defmodule Freguesia.VerificationTest do
  use Freguesia.DataCase, async: true

  import Ecto.Query

  alias Freguesia.Admin.AuditEntry
  alias Freguesia.Catalog.{Offer, Place}
  alias Freguesia.{Fixtures, Repo, Verification}
  alias Freguesia.Messaging.Fake
  alias Freguesia.Verification.{Code, Request}

  # Cadastra um lugar e devolve {place, e164}. O código fica no Fake.
  defp signup!(overrides \\ %{}) do
    params = Fixtures.signup_params(overrides)
    {:ok, place, :sent} = Verification.submit_signup(params)
    place
  end

  defp last_code(e164) do
    e164 |> Fake.sent_to() |> List.last() |> get_in([:params, "code"])
  end

  defp confirm!(place) do
    {:ok, request} = Verification.confirm_code(place.id, last_code(place.whatsapp_e164))
    request
  end

  defp templates_sent(e164), do: e164 |> Fake.sent_to() |> Enum.map(& &1.template)

  describe "submit_signup/1" do
    test "cria o lugar em pending e manda o código pelo WhatsApp" do
      place = signup!(%{"offer_text" => "10% no pedido direto"})

      assert place.status == :pending
      assert place.whatsapp_e164 =~ ~r/^\+55319\d{8}$/
      assert place.terms_accepted_at
      assert ["codigo_verificacao"] == templates_sent(place.whatsapp_e164)
      assert [%{params: %{"code" => code}}] = Fake.sent_to(place.whatsapp_e164)
      assert String.match?(code, ~r/^\d{6}$/)
    end

    test "o código nunca fica em texto puro no banco" do
      place = signup!()
      code = last_code(place.whatsapp_e164)

      stored = Repo.one!(from c in Code, where: c.place_id == ^place.id)
      refute stored.code_hash == code
      refute String.contains?(inspect(stored), code)
    end

    test "restaurante exige tipo de comida" do
      params = Fixtures.signup_params(%{"category_id" => nil})

      assert {:error, changeset} = Verification.submit_signup(params)
      assert {"escolha o tipo de comida", _} = changeset.errors[:category_id]
    end

    test "bairro fora do piloto é recusado" do
      outside = Fixtures.neighborhood(%{slug: "centro", name: "Centro", pilot: false})

      params =
        Fixtures.signup_params(%{"neighborhood_id" => outside.id, "coverage_ids" => [outside.id]})

      assert {:error, changeset} = Verification.submit_signup(params)
      assert changeset.errors[:neighborhood_id]
    end

    test "exige o aceite dos termos" do
      assert {:error, changeset} =
               Verification.submit_signup(Fixtures.signup_params(%{"accept_terms" => "false"}))

      assert changeset.errors[:accept_terms]
    end

    test "número já verificado não pode ser cadastrado de novo" do
      verified = Fixtures.verified_place(%{whatsapp_e164: "+5531988887777"})
      assert verified.status == :verified

      params = Fixtures.signup_params(%{"whatsapp" => "+5531988887777"})
      assert {:error, changeset} = Verification.submit_signup(params)
      assert changeset.errors[:whatsapp]
    end

    test "número com cadastro pendente é reaproveitado, não duplicado" do
      first = signup!(%{"name" => "Primeiro Nome"})
      second = signup!(%{"name" => "Nome Corrigido", "whatsapp" => first.whatsapp_e164})

      assert first.id == second.id
      assert Repo.get!(Place, first.id).name == "Nome Corrigido"
    end
  end

  describe "confirm_code/2" do
    test "código certo confirma e abre o pedido na fila" do
      place = signup!()
      request = confirm!(place)

      assert request.status == :pending
      assert request.place_id == place.id
    end

    test "código errado conta a tentativa e avisa quantas restam" do
      place = signup!()
      assert {:error, {:invalid_code, 2}} = Verification.confirm_code(place.id, "000000")
      assert {:error, {:invalid_code, 1}} = Verification.confirm_code(place.id, "000000")
    end

    test "três erros esgotam o código" do
      place = signup!()
      wrong = if last_code(place.whatsapp_e164) == "000000", do: "111111", else: "000000"

      for _ <- 1..3, do: Verification.confirm_code(place.id, wrong)

      assert {:error, :too_many_attempts} =
               Verification.confirm_code(place.id, last_code(place.whatsapp_e164))
    end

    test "código expirado é recusado" do
      place = signup!()
      code = last_code(place.whatsapp_e164)

      Repo.update_all(
        from(c in Code, where: c.place_id == ^place.id),
        set: [expires_at: DateTime.add(DateTime.utc_now(), -1)]
      )

      assert {:error, :expired} = Verification.confirm_code(place.id, code)
    end

    test "reenvio só depois de 60 segundos" do
      place = signup!()
      assert {:error, :too_soon} = Verification.resend_code(place.id)
    end

    test "reenvio depois de 60 segundos gera um código novo" do
      place = signup!()

      Repo.update_all(
        from(c in Code, where: c.place_id == ^place.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -61) |> DateTime.truncate(:second)]
      )

      assert {:ok, _code} = Verification.resend_code(place.id)
      assert length(Fake.sent_to(place.whatsapp_e164)) == 2
    end
  end

  describe "approve/3" do
    test "com as quatro checagens ok, publica sem nota" do
      place = signup!()
      request = confirm!(place)

      # Sem perfil do WhatsApp lido, a checagem de nome fica pending: precisa de nota.
      assert {:error, :checks_incomplete} = Verification.approve(request, nil)

      assert {:ok, approved} = Verification.approve(request, nil, "Perfil conferido à mão")
      assert approved.status == :approved

      place = Repo.get!(Place, place.id)
      assert place.status == :verified
      assert place.verified_at
    end

    test "nota interna libera a aprovação quando uma checagem está pendente" do
      place = signup!()
      request = confirm!(place)

      assert {:ok, _} =
               Verification.approve(request, nil, "Nome do perfil conferido por telefone")

      assert Repo.get!(Place, place.id).status == :verified
    end

    test "grava audit_log e manda a mensagem de aprovação com o link" do
      operator = Fixtures.operator()
      place = signup!()
      request = confirm!(place)

      {:ok, _} = Verification.approve(request, operator, "ok")

      assert [entry] =
               Repo.all(from a in AuditEntry, where: a.action == "verification.approve")

      assert entry.admin_id == operator.id
      assert entry.entity_id == place.id

      assert "lugar_aprovado" in templates_sent(place.whatsapp_e164)

      [message] =
        Fake.sent_to(place.whatsapp_e164) |> Enum.filter(&(&1.template == "lugar_aprovado"))

      assert message.params["url"] =~ "/lugar/"
    end

    test "aprovar de novo é idempotente: sem segunda mensagem nem segundo registro" do
      operator = Fixtures.operator()
      place = signup!()
      request = confirm!(place)

      {:ok, _} = Verification.approve(request, operator, "ok")
      assert {:ok, :already_approved} = Verification.approve(request, operator, "ok")

      assert Repo.aggregate(
               from(a in AuditEntry, where: a.action == "verification.approve"),
               :count
             ) == 1

      assert Enum.count(Fake.sent_to(place.whatsapp_e164), &(&1.template == "lugar_aprovado")) ==
               1
    end

    test "nova oferta aprovada tira a anterior do ar sem apagar o histórico" do
      place = signup!(%{"offer_text" => "Oferta antiga"})
      {:ok, _} = Verification.approve(confirm!(place), nil, "ok")

      # Edição do restaurante gera uma oferta nova pendente e um novo pedido
      Repo.insert!(%Offer{place_id: place.id, text: "Oferta nova", status: :pending})
      {:ok, _request} = Repo.insert(%Request{place_id: place.id, status: :pending, checks: %{}})

      second_request =
        Repo.one!(from r in Request, where: r.place_id == ^place.id and r.status == :pending)

      {:ok, _} = Verification.approve(second_request, nil, "ok")

      statuses =
        Repo.all(from o in Offer, where: o.place_id == ^place.id, select: {o.text, o.status})
        |> Map.new()

      assert statuses["Oferta nova"] == :approved
      assert statuses["Oferta antiga"] == :replaced
    end
  end

  describe "request_changes/3 e reject/3" do
    test "pedir ajuste exige motivo e manda a mensagem com o motivo" do
      place = signup!()
      request = confirm!(place)

      assert {:error, :reason_required} = Verification.request_changes(request, nil, "  ")

      assert {:ok, changed} =
               Verification.request_changes(request, nil, "Envie a foto da fachada")

      assert changed.status == :needs_changes
      assert Repo.get!(Place, place.id).status == :needs_changes

      [message] =
        Fake.sent_to(place.whatsapp_e164) |> Enum.filter(&(&1.template == "pedido_ajuste"))

      assert message.params["reason"] == "Envie a foto da fachada"
    end

    test "pedir ajuste de novo é idempotente" do
      place = signup!()
      request = confirm!(place)

      {:ok, _} = Verification.request_changes(request, nil, "Foto")
      assert {:ok, :already_requested} = Verification.request_changes(request, nil, "Foto")
      assert Enum.count(Fake.sent_to(place.whatsapp_e164), &(&1.template == "pedido_ajuste")) == 1
    end

    test "recusar exige motivo e marca o lugar como rejected" do
      place = signup!()
      request = confirm!(place)

      assert {:error, :reason_required} = Verification.reject(request, nil, "")
      assert {:ok, _} = Verification.reject(request, nil, "Número de cliente, não de restaurante")
      assert Repo.get!(Place, place.id).status == :rejected
    end

    test "não se pode recusar um pedido já aprovado" do
      place = signup!()
      request = confirm!(place)
      {:ok, _} = Verification.approve(request, nil, "ok")

      assert {:error, :already_decided} = Verification.reject(request, nil, "mudei de ideia")
      assert Repo.get!(Place, place.id).status == :verified
    end

    test "número recusado só volta a tentar depois de 30 dias" do
      place = signup!()
      request = confirm!(place)
      {:ok, _} = Verification.reject(request, nil, "Número errado")

      params = Fixtures.signup_params(%{"whatsapp" => place.whatsapp_e164})
      assert {:error, changeset} = Verification.submit_signup(params)
      assert {msg, _} = changeset.errors[:whatsapp]
      assert msg =~ "só pode tentar de novo a partir de"
    end
  end

  describe "fila" do
    test "list_requests filtra por status e traz o lugar com bairro e tipo" do
      place = signup!()
      _request = confirm!(place)

      [found] = Verification.list_requests(:pending)
      assert found.place.id == place.id
      assert found.place.neighborhood.name == "Savassi"
      assert found.place.segment.key == "restaurants"

      assert Verification.list_requests(:approved) == []
    end

    test "start_review é idempotente e move de pending para in_review" do
      operator = Fixtures.operator()
      place = signup!()
      request = confirm!(place)

      {:ok, reviewed} = Verification.start_review(request, operator)
      assert reviewed.status == :in_review

      assert {:ok, same} = Verification.start_review(reviewed, operator)
      assert same.status == :in_review
    end
  end

  describe "checagens" do
    test "perfil do WhatsApp com nome parecido passa, nome diferente falha" do
      place = signup!(%{"name" => "Pizzaria do Zé"})
      request = confirm!(place)

      Repo.update_all(from(p in Place, where: p.id == ^place.id),
        set: [wa_profile_name: "Pizzaria do Ze"]
      )

      assert Verification.evaluate_checks(Verification.get_request(request.id))["profile_name"] ==
               "ok"

      Repo.update_all(from(p in Place, where: p.id == ^place.id),
        set: [wa_profile_name: "Sushi Total"]
      )

      assert Verification.evaluate_checks(Verification.get_request(request.id))["profile_name"] ==
               "fail"
    end
  end
end
