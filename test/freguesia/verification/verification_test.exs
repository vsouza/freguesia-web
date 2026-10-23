defmodule Freguesia.VerificationTest do
  use Freguesia.DataCase, async: true

  import Ecto.Query

  alias Freguesia.Admin.AuditEntry
  alias Freguesia.Catalog.{Offer, Place}
  alias Freguesia.{Fixtures, Repo, Verification}
  alias Freguesia.Messaging.Fake
  alias Freguesia.Verification.{Code, Request}

  # Signs up a place and returns {place, e164}. The code stays in the Fake.
  defp signup!(overrides \\ %{}, owner \\ nil) do
    params = Fixtures.signup_params(overrides)
    owner = owner || Fixtures.business_account()
    {:ok, place, :sent} = Verification.submit_signup(params, owner.id, [])
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

  describe "submit_signup/2" do
    test "creates the place as pending and sends the code over WhatsApp" do
      place = signup!(%{"offer_text" => "10% no pedido direto"})

      assert place.status == :pending
      assert place.whatsapp_e164 =~ ~r/^\+55319\d{8}$/
      assert place.terms_accepted_at
      assert ["verification_code"] == templates_sent(place.whatsapp_e164)
      assert [%{params: %{"code" => code}}] = Fake.sent_to(place.whatsapp_e164)
      assert String.match?(code, ~r/^\d{6}$/)
    end

    test "the code is never stored in plain text in the database" do
      place = signup!()
      code = last_code(place.whatsapp_e164)

      stored = Repo.one!(from c in Code, where: c.place_id == ^place.id)
      refute stored.code_hash == code
      refute String.contains?(inspect(stored), code)
    end

    test "restaurant requires a cuisine type" do
      params = Fixtures.signup_params(%{"category_id" => nil})

      assert {:error, changeset} =
               Verification.submit_signup(params, Fixtures.business_account().id, [])

      assert {"escolha o tipo de comida", _} = changeset.errors[:category_id]
    end

    test "neighborhood outside the pilot is rejected" do
      outside = Fixtures.neighborhood(%{slug: "centro", name: "Centro", pilot: false})

      params =
        Fixtures.signup_params(%{"neighborhood_id" => outside.id, "coverage_ids" => [outside.id]})

      assert {:error, changeset} =
               Verification.submit_signup(params, Fixtures.business_account().id, [])

      assert changeset.errors[:neighborhood_id]
    end

    test "requires acceptance of the terms" do
      assert {:error, changeset} =
               Verification.submit_signup(
                 Fixtures.signup_params(%{"accept_terms" => "false"}),
                 Fixtures.business_account().id,
                 []
               )

      assert changeset.errors[:accept_terms]
    end

    test "an already verified number cannot be registered again" do
      verified = Fixtures.verified_place(%{whatsapp_e164: "+5531988887777"})
      assert verified.status == :verified

      params = Fixtures.signup_params(%{"whatsapp" => "+5531988887777"})

      assert {:error, changeset} =
               Verification.submit_signup(params, Fixtures.business_account().id, [])

      assert changeset.errors[:whatsapp]
    end

    test "a number with a pending signup is reused, not duplicated" do
      owner = Fixtures.business_account()
      first = signup!(%{"name" => "Primeiro Nome"}, owner)
      second = signup!(%{"name" => "Nome Corrigido", "whatsapp" => first.whatsapp_e164}, owner)

      assert first.id == second.id
      assert Repo.get!(Place, first.id).name == "Nome Corrigido"
    end

    test "a number registered by another account cannot be taken over" do
      first = signup!(%{"name" => "Primeiro Nome"})

      assert {:error, changeset} =
               Verification.submit_signup(
                 Fixtures.signup_params(%{
                   "name" => "Outra Conta",
                   "whatsapp" => first.whatsapp_e164
                 }),
                 Fixtures.business_account().id,
                 []
               )

      assert changeset.errors[:whatsapp]
    end
  end

  describe "confirm_code/2" do
    test "correct code confirms and opens the request in the queue" do
      place = signup!()
      request = confirm!(place)

      assert request.status == :pending
      assert request.place_id == place.id
    end

    test "wrong code counts as an attempt and reports how many remain" do
      place = signup!()
      assert {:error, {:invalid_code, 2}} = Verification.confirm_code(place.id, "000000")
      assert {:error, {:invalid_code, 1}} = Verification.confirm_code(place.id, "000000")
    end

    test "three errors exhaust the code" do
      place = signup!()
      wrong = if last_code(place.whatsapp_e164) == "000000", do: "111111", else: "000000"

      for _ <- 1..3, do: Verification.confirm_code(place.id, wrong)

      assert {:error, :too_many_attempts} =
               Verification.confirm_code(place.id, last_code(place.whatsapp_e164))
    end

    test "expired code is rejected" do
      place = signup!()
      code = last_code(place.whatsapp_e164)

      Repo.update_all(
        from(c in Code, where: c.place_id == ^place.id),
        set: [expires_at: DateTime.add(DateTime.utc_now(), -1)]
      )

      assert {:error, :expired} = Verification.confirm_code(place.id, code)
    end

    test "resend only after 60 seconds" do
      place = signup!()
      assert {:error, :too_soon} = Verification.resend_code(place.id, [])
    end

    test "resend after 60 seconds generates a new code" do
      place = signup!()

      Repo.update_all(
        from(c in Code, where: c.place_id == ^place.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -61) |> DateTime.truncate(:second)]
      )

      assert {:ok, _code} = Verification.resend_code(place.id, [])
      assert length(Fake.sent_to(place.whatsapp_e164)) == 2
    end
  end

  describe "approve/3" do
    test "with all four checks passing, publishes without a note" do
      place = signup!()
      request = confirm!(place)

      # Without a WhatsApp profile read, the name check stays pending: a note is required.
      assert {:error, :checks_incomplete} = Verification.approve(request, nil)

      assert {:ok, approved} = Verification.approve(request, nil, "Perfil conferido à mão")
      assert approved.status == :approved

      place = Repo.get!(Place, place.id)
      assert place.status == :verified
      assert place.verified_at
    end

    test "internal note allows approval while a check is pending" do
      place = signup!()
      request = confirm!(place)

      assert {:ok, _} =
               Verification.approve(request, nil, "Nome do perfil conferido por telefone")

      assert Repo.get!(Place, place.id).status == :verified
    end

    test "writes audit_log and sends the approval message with the link" do
      operator = Fixtures.operator()
      place = signup!()
      request = confirm!(place)

      {:ok, _} = Verification.approve(request, operator, "ok")

      assert [entry] =
               Repo.all(from a in AuditEntry, where: a.action == "verification.approve")

      assert entry.admin_id == operator.id
      assert entry.entity_id == place.id

      assert "place_approved" in templates_sent(place.whatsapp_e164)

      [message] =
        Fake.sent_to(place.whatsapp_e164) |> Enum.filter(&(&1.template == "place_approved"))

      assert message.params["url"] =~ "/places/"
    end

    test "approving again is idempotent: no second message or audit entry" do
      operator = Fixtures.operator()
      place = signup!()
      request = confirm!(place)

      {:ok, _} = Verification.approve(request, operator, "ok")
      assert {:ok, :already_approved} = Verification.approve(request, operator, "ok")

      assert Repo.aggregate(
               from(a in AuditEntry, where: a.action == "verification.approve"),
               :count
             ) == 1

      assert Enum.count(Fake.sent_to(place.whatsapp_e164), &(&1.template == "place_approved")) ==
               1
    end

    test "a newly approved offer takes the previous one off the air without deleting history" do
      place = signup!(%{"offer_text" => "Oferta antiga"})
      {:ok, _} = Verification.approve(confirm!(place), nil, "ok")

      # A restaurant edit creates a new pending offer and a new request
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

  describe "request_changes/3 and reject/3" do
    test "requesting an adjustment requires a reason and sends the message with it" do
      place = signup!()
      request = confirm!(place)

      assert {:error, :reason_required} = Verification.request_changes(request, nil, "  ")

      assert {:ok, changed} =
               Verification.request_changes(request, nil, "Envie a foto da fachada")

      assert changed.status == :needs_changes
      assert Repo.get!(Place, place.id).status == :needs_changes

      [message] =
        Fake.sent_to(place.whatsapp_e164) |> Enum.filter(&(&1.template == "adjustment_request"))

      assert message.params["reason"] == "Envie a foto da fachada"
    end

    test "requesting an adjustment again is idempotent" do
      place = signup!()
      request = confirm!(place)

      {:ok, _} = Verification.request_changes(request, nil, "Foto")
      assert {:ok, :already_requested} = Verification.request_changes(request, nil, "Foto")

      assert Enum.count(Fake.sent_to(place.whatsapp_e164), &(&1.template == "adjustment_request")) ==
               1
    end

    test "rejecting requires a reason and marks the place as rejected" do
      place = signup!()
      request = confirm!(place)

      assert {:error, :reason_required} = Verification.reject(request, nil, "")
      assert {:ok, _} = Verification.reject(request, nil, "Número de cliente, não de restaurante")
      assert Repo.get!(Place, place.id).status == :rejected
    end

    test "an already approved request cannot be rejected" do
      place = signup!()
      request = confirm!(place)
      {:ok, _} = Verification.approve(request, nil, "ok")

      assert {:error, :already_decided} = Verification.reject(request, nil, "mudei de ideia")
      assert Repo.get!(Place, place.id).status == :verified
    end

    test "a rejected number can only try again after 30 days" do
      place = signup!()
      request = confirm!(place)
      {:ok, _} = Verification.reject(request, nil, "Número errado")

      params = Fixtures.signup_params(%{"whatsapp" => place.whatsapp_e164})

      assert {:error, changeset} =
               Verification.submit_signup(params, Fixtures.business_account().id, [])

      assert {msg, _} = changeset.errors[:whatsapp]
      assert msg =~ "só pode tentar de novo a partir de"
    end
  end

  describe "queue" do
    test "list_requests filters by status and preloads the place with its neighborhood and type" do
      place = signup!()
      _request = confirm!(place)

      [found] = Verification.list_requests(:pending)
      assert found.place.id == place.id
      assert found.place.neighborhood.name == "Savassi"
      assert found.place.segment.key == "restaurants"

      assert Verification.list_requests(:approved) == []
    end

    test "start_review is idempotent and moves pending to in_review" do
      operator = Fixtures.operator()
      place = signup!()
      request = confirm!(place)

      {:ok, reviewed} = Verification.start_review(request, operator)
      assert reviewed.status == :in_review

      assert {:ok, same} = Verification.start_review(reviewed, operator)
      assert same.status == :in_review
    end
  end

  describe "checks" do
    test "WhatsApp profile with a similar name passes, a different name fails" do
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
