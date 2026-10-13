defmodule FreguesiaWeb.LoopTest do
  @moduledoc "WhatsApp loop on the web layer: redirect, cookie, return sheet and proofs."
  use FreguesiaWeb.ConnCase, async: true

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest

  alias Freguesia.{Fixtures, Repo, Reports}
  alias Freguesia.Reports.{Complaint, Open, Report, Stats}

  defp visit(conn, place) do
    conn = get(conn, ~p"/places/#{place.slug}")
    {conn, Plug.Conn.get_session(conn, "device_id")}
  end

  describe "GET /places/:slug/whatsapp" do
    test "records the opening and redirects to the place's wa.me link" do
      place = Fixtures.verified_place(%{whatsapp_e164: "+5531977776666"})

      conn = get(build_conn(), ~p"/places/#{place.slug}/whatsapp")

      assert redirected_to(conn, 302) =~ "https://wa.me/5531977776666?text="
      assert Repo.aggregate(from(o in Open, where: o.place_id == ^place.id), :count) == 1
    end

    test "device cookie is created on the first visit and reused afterwards" do
      place = Fixtures.verified_place()

      first = get(build_conn(), ~p"/places/#{place.slug}/whatsapp")
      device = first.assigns.device_id
      assert device

      second = first |> recycle() |> get(~p"/places/#{place.slug}/whatsapp")
      assert second.assigns.device_id == device
    end

    test "place with a hidden button records no opening and returns to the place page" do
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

      conn = get(build_conn(), ~p"/places/#{place.slug}/whatsapp")

      assert redirected_to(conn) == ~p"/places/#{place.slug}"
      assert Repo.aggregate(from(o in Open, where: o.place_id == ^place.id), :count) == 0
    end

    test "paused place records no opening" do
      place =
        Fixtures.verified_place(%{
          paused_until: DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), 3600)
        })

      conn = get(build_conn(), ~p"/places/#{place.slug}/whatsapp")

      assert redirected_to(conn) == ~p"/places/#{place.slug}"
      assert Repo.aggregate(from(o in Open, where: o.place_id == ^place.id), :count) == 0
    end

    test "place not in the catalog redirects to the neighborhood" do
      conn = get(build_conn(), ~p"/places/nao-existe/whatsapp")
      assert redirected_to(conn) == ~p"/areas/savassi"
    end
  end

  describe "return sheet" do
    test "shows up when the tab regains focus and there is a pending opening" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, _open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")
      # on entry the sheet already shows; the focus event does not open a second one
      assert has_element?(view, "#return-sheet", "Conseguiu pedir direto?")

      render_hook(view, "returned", %{})
      assert has_element?(view, "#return-sheet", "Conseguiu pedir direto?")
    end

    test "opening the page with a pending opening shows the sheet, with no focus event" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, _open} = Reports.open_whatsapp(place.id, device)

      # Came back through history: the page loads again, with no visibilitychange
      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")
      assert has_element?(view, "#return-sheet", "Conseguiu pedir direto?")
    end

    test "the WhatsApp button opens in a new tab, and the original page stays open" do
      place = Fixtures.verified_place()
      {:ok, view, _html} = live(build_conn(), ~p"/places/#{place.slug}")

      assert has_element?(
               view,
               "a#whatsapp-cta[href='/places/#{place.slug}/whatsapp'][target='_blank']"
             )
    end

    test "without a pending opening, the sheet does not appear" do
      place = Fixtures.verified_place()
      {conn, _device} = visit(build_conn(), place)

      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")
      render_hook(view, "returned", %{})

      refute has_element?(view, "#return-sheet")
    end

    test "yes, then a savings band, records the report and closes the sheet" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")
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

    test "no, then reason, records a failure" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")
      render_hook(view, "returned", %{})

      view |> element("#sheet-no") |> render_click()
      view |> element("#reason-no_coverage") |> render_click()

      report = Repo.one!(from r in Report, where: r.open_id == ^open.id)
      assert report.outcome == :failed
      assert report.fail_reason == :no_coverage
    end

    test "wrong number or scam opens a complaint" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, _open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")
      render_hook(view, "returned", %{})
      view |> element("#sheet-no") |> render_click()
      view |> element("#reason-wrong_or_scam") |> render_click()

      assert Repo.aggregate(from(c in Complaint, where: c.place_id == ^place.id), :count) == 1
    end

    test "answering later closes the sheet and the opening stays pending" do
      place = Fixtures.verified_place()
      {conn, device} = visit(build_conn(), place)
      {:ok, _open} = Reports.open_whatsapp(place.id, device)

      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")
      render_hook(view, "returned", %{})
      view |> element("#sheet-later") |> render_click()

      refute has_element?(view, "#return-sheet")
      assert Reports.pending_open(place.id, device)
    end
  end

  describe "savings proofs" do
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

    test "with 10 or more reports shows the average and its source" do
      place = Fixtures.verified_place()
      answer_many!(place, 10, "le10")

      {:ok, _view, html} = live(build_conn(), ~p"/places/#{place.slug}")

      assert html =~ "a menos, em média, do que nos apps"
      assert html =~ "Relatado por 10 fregueses nos últimos 90 dias. Pode variar."
      refute html =~ "Poucos relatos"
    end

    test "under 10 reports shows no average, only the invitation to report" do
      place = Fixtures.verified_place()
      answer_many!(place, 3, "le10")

      {:ok, _view, html} = live(build_conn(), ~p"/places/#{place.slug}")

      assert html =~ "Poucos relatos até agora (3)"
      refute html =~ "a menos, em média, do que nos apps"
    end

    test "'worked' only shows with responses, and the bar only with 5 or more" do
      place = Fixtures.verified_place()
      answer_many!(place, 3, "le10")

      {:ok, view, _html} = live(build_conn(), ~p"/places/#{place.slug}")
      assert has_element?(view, "#proof-funcionou", "Funcionou 3/3 em 30 dias")
      refute has_element?(view, "#proof-funcionou [aria-hidden] div")
    end
  end
end
