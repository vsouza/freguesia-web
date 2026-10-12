defmodule FreguesiaWeb.LoopTest do
  @moduledoc "Loop do WhatsApp na camada web: redirect, cookie, folha de retorno e provas."
  use FreguesiaWeb.ConnCase, async: true

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest

  alias Freguesia.{Fixtures, Repo, Reports}
  alias Freguesia.Reports.{Complaint, Open, Report, Stats}

  defp visit(conn, place) do
    conn = get(conn, ~p"/lugar/#{place.slug}")
    {conn, Plug.Conn.get_session(conn, "device_id")}
  end

  describe "GET /r/:slug" do
    test "registra a abertura e manda para o wa.me do lugar" do
      place = Fixtures.verified_place(%{whatsapp_e164: "+5531977776666"})

      conn = get(build_conn(), ~p"/r/#{place.slug}")

      assert redirected_to(conn, 302) =~ "https://wa.me/5531977776666?text="
      assert Repo.aggregate(from(o in Open, where: o.place_id == ^place.id), :count) == 1
    end

    test "cookie de dispositivo é criado no primeiro acesso e reaproveitado depois" do
      place = Fixtures.verified_place()

      first = get(build_conn(), ~p"/r/#{place.slug}")
      device = first.assigns.device_id
      assert device

      second = first |> recycle() |> get(~p"/r/#{place.slug}")
      assert second.assigns.device_id == device
    end

    test "lugar com botão escondido não registra abertura e volta à página do lugar" do
      place = Fixtures.verified_place()

      for _ <- 1..2 do
        Repo.insert!(%Complaint{
          place_id: place.id,
          source: :report,
          reason: :wrong_or_scam,
          status: :open,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
      end

      conn = get(build_conn(), ~p"/r/#{place.slug}")

      assert redirected_to(conn) == ~p"/lugar/#{place.slug}"
      assert Repo.aggregate(from(o in Open, where: o.place_id == ^place.id), :count) == 0
    end

    test "lugar pausado não registra abertura" do
      place =
        Fixtures.verified_place(%{
          paused_until: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 3600)
        })

      conn = get(build_conn(), ~p"/r/#{place.slug}")

      assert redirected_to(conn) == ~p"/lugar/#{place.slug}"
      assert Repo.aggregate(from(o in Open, where: o.place_id == ^place.id), :count) == 0
    end

    test "lugar que não está no catálogo volta ao bairro" do
      conn = get(build_conn(), ~p"/r/nao-existe")
      assert redirected_to(conn) == ~p"/bairro/savassi"
    end
  end

  describe "folha de retorno" do
    test "aparece quando a aba volta ao foco e há abertura pendente" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, _open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/lugar/#{place.slug}")
      # ao entrar, a folha já aparece; o evento de foco não abre uma segunda
      assert has_element?(view, "#return-sheet", "Conseguiu pedir direto?")

      render_hook(view, "returned", %{})
      assert has_element?(view, "#return-sheet", "Conseguiu pedir direto?")
    end

    test "entrar na página com abertura pendente abre a folha, sem evento de foco" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, _open} = Reports.open_whatsapp(place.id, device)

      # Voltou pelo histórico: a página carrega de novo, sem visibilitychange
      {:ok, view, _html} = live(conn, ~p"/lugar/#{place.slug}")
      assert has_element?(view, "#return-sheet", "Conseguiu pedir direto?")
    end

    test "o botão de WhatsApp abre em nova aba, e a página original continua aberta" do
      place = Fixtures.verified_place()
      {:ok, view, _html} = live(build_conn(), ~p"/lugar/#{place.slug}")

      assert has_element?(view, "a#whatsapp-cta[href='/r/#{place.slug}'][target='_blank']")
    end

    test "sem abertura pendente, a folha não aparece" do
      place = Fixtures.verified_place()
      {conn, _device} = visit(build_conn(), place)

      {:ok, view, _html} = live(conn, ~p"/lugar/#{place.slug}")
      render_hook(view, "returned", %{})

      refute has_element?(view, "#return-sheet")
    end

    test "sim, depois faixa de economia, grava o relato e fecha a folha" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/lugar/#{place.slug}")
      render_hook(view, "returned", %{})

      view |> element("#sheet-yes") |> render_click()
      assert has_element?(view, "#band-le10")

      view |> element("#band-le10") |> render_click()

      refute has_element?(view, "#return-sheet")
      assert render(view) =~ "Valeu"

      report = Repo.one!(from r in Report, where: r.open_id == ^open.id)
      assert report.outcome == :worked
      assert report.savings_band == "le10"
      assert Repo.get!(Open, open.id).responded_at
    end

    test "não, depois motivo, grava falha" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/lugar/#{place.slug}")
      render_hook(view, "returned", %{})

      view |> element("#sheet-no") |> render_click()
      view |> element("#reason-no_coverage") |> render_click()

      report = Repo.one!(from r in Report, where: r.open_id == ^open.id)
      assert report.outcome == :failed
      assert report.fail_reason == :no_coverage
    end

    test "número errado ou golpe abre denúncia" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, _open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/lugar/#{place.slug}")
      render_hook(view, "returned", %{})
      view |> element("#sheet-no") |> render_click()
      view |> element("#reason-wrong_or_scam") |> render_click()

      assert Repo.aggregate(from(c in Complaint, where: c.place_id == ^place.id), :count) == 1
    end

    test "responder depois fecha a folha e a abertura continua pendente" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, _open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/lugar/#{place.slug}")
      render_hook(view, "returned", %{})
      view |> element("#sheet-later") |> render_click()

      refute has_element?(view, "#return-sheet")
      assert Reports.pending_open(place.id, device)
    end
  end

  describe "provas da economia" do
    defp answer_many!(place, n, band) do
      for _ <- 1..n do
        device = Ecto.UUID.generate()
        {:ok, open} = Reports.open_whatsapp(place.id, device)

        {:ok, _} =
          Reports.answer(open.id, %{outcome: :worked, band: band}, %{
            device_id: device,
            ip24_hash: nil
          })
      end

      Stats.refresh()
    end

    test "com 10 ou mais relatos mostra a média e a fonte" do
      place = Fixtures.verified_place()
      answer_many!(place, 10, "le10")

      {:ok, _view, html} = live(build_conn(), ~p"/lugar/#{place.slug}")

      assert html =~ "a menos, em média, do que nos apps"
      assert html =~ "Relatado por 10 fregueses nos últimos 90 dias. Pode variar."
      refute html =~ "Poucos relatos"
    end

    test "abaixo de 10 relatos não mostra média, só o convite para contar" do
      place = Fixtures.verified_place()
      answer_many!(place, 3, "le10")

      {:ok, _view, html} = live(build_conn(), ~p"/lugar/#{place.slug}")

      assert html =~ "Poucos relatos até agora (3)"
      refute html =~ "a menos, em média, do que nos apps"
    end

    test "funcionou só aparece com resposta, e a barra só com 5 ou mais" do
      place = Fixtures.verified_place()
      answer_many!(place, 3, "le10")

      {:ok, view, _html} = live(build_conn(), ~p"/lugar/#{place.slug}")
      assert has_element?(view, "#proof-funcionou", "Funcionou 3/3 em 30 dias")
      refute has_element?(view, "#proof-funcionou [aria-hidden] div")
    end
  end
end
