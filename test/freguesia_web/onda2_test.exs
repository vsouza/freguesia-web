defmodule FreguesiaWeb.Onda2Test do
  @moduledoc "Phase 1, wave 2: welcome, location, home filters, search, details and navigation."
  use FreguesiaWeb.ConnCase, async: true

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest

  alias Freguesia.{Catalog, Fixtures, Repo}
  alias Freguesia.Catalog.{Offer, Place}
  alias Freguesia.Verification.Request

  # A point inside the test polygon of Savassi (see Fixtures.reference_data!/0).
  @inside_savassi {-19.9372, -43.9378}
  @outside_pilot {-19.5, -43.5}

  describe "welcome and onboarding" do
    test "/start marks the device as onboarded and goes to location", %{conn: conn} do
      conn = get(conn, ~p"/start")

      assert redirected_to(conn) == ~p"/location"
      assert conn.resp_cookies["onboarded"].value == "1"
    end

    test "a device that saw the welcome screen goes straight to the saved neighborhood", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_cookie("onboarded", "1")
        |> init_test_session(%{"neighborhood" => "lourdes"})
        |> get(~p"/")

      assert redirected_to(conn) == "/areas/lourdes"
    end
  end

  describe "location" do
    test "a point inside the pilot resolves to its neighborhood, without storing it", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/location")
      {lat, lng} = @inside_savassi

      assert {:error, {:redirect, %{to: "/location/savassi?via=geo"}}} =
               render_hook(view, "located", %{"lat" => lat, "lng" => lng})
    end

    test "a point outside the pilot asks for a manual choice", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/location")
      {lat, lng} = @outside_pilot

      html = render_hook(view, "located", %{"lat" => lat, "lng" => lng})

      assert html =~ "You are outside the pilot area" or
               html =~ "Você está fora da área do piloto"
    end

    test "denied permission falls back to the manual list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/location")
      html = render_hook(view, "denied", %{})
      assert html =~ "We could not get your location" or html =~ "Não conseguimos sua localização"
    end

    test "a manual choice stores the neighborhood in the session and opens its home", %{
      conn: conn
    } do
      conn = get(conn, ~p"/location/lourdes?via=manual")

      assert redirected_to(conn) == "/areas/lourdes"
      assert get_session(conn, "neighborhood") == "lourdes"
    end

    test "an unknown neighborhood goes back to the location step", %{conn: conn} do
      conn = get(conn, ~p"/location/atlantis")
      assert redirected_to(conn) == ~p"/location"
    end

    test "pilot lookup uses PostGIS and ignores points outside every polygon" do
      {lat, lng} = @inside_savassi
      assert %{slug: "savassi"} = Catalog.pilot_neighborhood_at(lat, lng)

      {out_lat, out_lng} = @outside_pilot
      assert Catalog.pilot_neighborhood_at(out_lat, out_lng) == nil
      assert Catalog.pilot_neighborhood_at(nil, nil) == nil
    end
  end

  describe "home filters" do
    setup do
      neighborhood = Fixtures.neighborhood()
      pizza = Fixtures.verified_place(%{name: "Pizza do Centro", neighborhood: neighborhood})
      %{neighborhood: neighborhood, pizza: pizza}
    end

    test "shows the segment and food-type chips, with restaurants selected by default", %{
      conn: conn,
      pizza: pizza
    } do
      {:ok, view, _html} = live(conn, ~p"/areas/savassi")

      assert has_element?(view, "#segment-all[aria-pressed=true]")
      assert has_element?(view, "#segment-restaurants")
      assert has_element?(view, "#places", pizza.name)
    end

    test "food-type chips appear only for restaurants", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/areas/savassi")
      refute has_element?(view, "#category-pizza")

      {:ok, view, _html} = live(conn, ~p"/areas/savassi?segment=restaurants")
      assert has_element?(view, "#category-pizza")
    end

    test "the search matches names without accents and ignores case", %{conn: conn} do
      Fixtures.verified_place(%{name: "Açaí da Praça", neighborhood: Fixtures.neighborhood()})

      {:ok, view, _html} = live(conn, ~p"/areas/savassi?q=acai")
      assert has_element?(view, "#places", "Açaí da Praça")
    end

    test "a search with no match shows nothing found and clears the filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/areas/savassi?q=zzzz")

      assert has_element?(view, "#nothing-found")
      assert has_element?(view, "a", "Limpar filtros")
    end

    test "a segment without places shows coming soon and a way to suggest a place", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/areas/savassi?segment=pharmacies")

      assert has_element?(view, "#coming-soon")
      assert has_element?(view, "a[href='/business/register']", "Cadastrar lugar")
    end

    test "open-now and with-perk filters narrow the list", %{
      conn: conn,
      neighborhood: neighborhood
    } do
      closed =
        Fixtures.verified_place(%{
          name: "Fechado Hoje",
          neighborhood: neighborhood,
          opening_hours: %{}
        })

      Repo.insert!(%Offer{
        place_id: closed.id,
        text: "10% off",
        tag: "10% off",
        status: :approved,
        approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      {:ok, view, _html} = live(conn, ~p"/areas/savassi?open=1")
      refute has_element?(view, "#places", "Fechado Hoje")

      {:ok, view, _html} = live(conn, ~p"/areas/savassi?perk=1")
      assert has_element?(view, "#places", "Fechado Hoje")
    end

    test "the business band links to registration", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/areas/savassi")
      assert has_element?(view, "#for-businesses a[href='/business/register']")
    end
  end

  describe "search screen" do
    test "asks for a name before searching", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      assert has_element?(view, "#search-prompt")
    end

    test "finds verified places across the pilot", %{conn: conn} do
      Fixtures.verified_place(%{name: "Trattoria do Sul", neighborhood: Fixtures.neighborhood()})

      {:ok, view, _html} = live(conn, ~p"/search?q=trattoria")
      assert has_element?(view, "#search-results", "Trattoria do Sul")
    end

    test "unverified places never show up in search", %{conn: conn} do
      place =
        Fixtures.verified_place(%{
          name: "Pendente Secreto",
          neighborhood: Fixtures.neighborhood()
        })

      Repo.update_all(from(p in Place, where: p.id == ^place.id), set: [status: :pending])

      {:ok, view, _html} = live(conn, ~p"/search?q=pendente")
      assert has_element?(view, "#search-nothing-found")
    end

    test "the bottom navigation marks Search as the active tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")
      assert has_element?(view, "nav a[aria-current=page]", "Buscar")
    end
  end

  describe "place details" do
    test "the page carries Open Graph tags for link previews", %{conn: conn} do
      place = Fixtures.verified_place(%{name: "Cantina Azul"})
      html = conn |> get(~p"/places/#{place.slug}") |> html_response(200)

      assert html =~ ~s(property="og:title" content="Cantina Azul")
      assert html =~ ~s(property="og:type" content="business.business")
    end

    test "the details page explains how ordering direct works", %{conn: conn} do
      place = Fixtures.verified_place()
      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")
      assert has_element?(view, "#about-direct", "Sobre o pedido direto")
    end

    test "reporting a number opens a case from the form and hides the button after two", %{
      conn: conn
    } do
      place = Fixtures.verified_place()
      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")

      for _ <- 1..2 do
        view |> element("#report-open") |> render_click()

        view
        |> form("#report-form", report: %{reason: "wrong_or_scam", details: "Golpe"})
        |> render_submit()
      end

      assert Repo.aggregate(
               from(c in Freguesia.Reports.Complaint,
                 where: c.place_id == ^place.id and c.source == :form
               ),
               :count
             ) == 2

      assert has_element?(view, "#whatsapp-cta", "Número em revisão") or
               has_element?(view, "#whatsapp-cta", "Under review")
    end
  end
end
