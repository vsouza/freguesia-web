defmodule FreguesiaWeb.ConsumerLiveTest do
  use FreguesiaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Freguesia.Catalog.Place
  alias Freguesia.{Fixtures, Repo}
  alias Freguesia.Messaging.Fake

  describe "neighborhood home (/areas/:neighborhood)" do
    test "lists verified places and does not list pending ones", %{conn: conn} do
      neighborhood = Fixtures.neighborhood()
      verified = Fixtures.verified_place(%{name: "Pizzaria Visível", neighborhood: neighborhood})
      pending = Fixtures.verified_place(%{name: "Pizzaria Oculta", neighborhood: neighborhood})
      Repo.update_all(from_place(pending), set: [status: :pending])

      {:ok, view, _html} = live(conn, ~p"/areas/savassi")

      assert has_element?(view, "#place-card-#{verified.slug}")
      refute render(view) =~ "Pizzaria Oculta"
    end

    test "shows the Verified badge and the offer tag when there is an offer summary", %{
      conn: conn
    } do
      neighborhood = Fixtures.neighborhood()
      place = Fixtures.verified_place(%{name: "Com Selo", neighborhood: neighborhood})

      Repo.insert!(%Freguesia.Catalog.Offer{
        place_id: place.id,
        text: "10% no pedido direto",
        tag: "10% off",
        status: :approved,
        approved_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      {:ok, view, _html} = live(conn, ~p"/areas/savassi")

      assert has_element?(view, "#place-card-#{place.slug}", "Verificado")
      assert has_element?(view, "#place-card-#{place.slug}", "10% off")
      # The full offer text does not go to the card (rule 4)
      refute has_element?(view, "#place-card-#{place.slug}", "10% no pedido direto")
    end

    test "neighborhood without places shows the empty state", %{conn: conn} do
      Fixtures.neighborhood()
      {:ok, view, html} = live(conn, ~p"/areas/savassi")

      assert html =~ "Chegam em breve"
      assert has_element?(view, "#places")
    end

    test "unknown neighborhood falls back to Savassi", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/areas/savassi"}}} =
               live(conn, ~p"/areas/nao-existe")
    end

    test "first visit shows the welcome screen", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Começar"
    end

    test "a device that already saw the welcome goes to its neighborhood", %{conn: conn} do
      conn =
        conn
        |> put_req_cookie("onboarded", "1")
        |> get(~p"/")

      assert redirected_to(conn) == "/areas/savassi"
    end
  end

  describe "place details (/places/:slug)" do
    test "verified place shows the WhatsApp button that goes through the opening record", %{
      conn: conn
    } do
      place = Fixtures.verified_place(%{name: "Pizza do Lago", whatsapp_e164: "+5531977776666"})

      {:ok, view, _html} = live(conn, ~p"/places/#{place.slug}")

      assert has_element?(view, "a#whatsapp-cta[href='/places/#{place.slug}/whatsapp']")
    end

    test "paused place shows its status and offers no order button", %{conn: conn} do
      place = Fixtures.verified_place(%{name: "Pausado"})

      Repo.update_all(from_place(place),
        set: [paused_until: DateTime.add(DateTime.utc_now(), 3600)]
      )

      {:ok, view, html} = live(conn, ~p"/places/#{place.slug}")
      assert html =~ "Sem atender hoje"
      refute has_element?(view, "a#whatsapp-cta")
    end

    test "place not in the catalog goes back to the neighborhood", %{conn: conn} do
      place = Fixtures.verified_place(%{name: "Pendente Escondido"})
      Repo.update_all(from_place(place), set: [status: :pending])

      assert {:error, {:live_redirect, %{to: "/areas/savassi"}}} =
               live(conn, ~p"/places/#{place.slug}")
    end
  end

  describe "3-step signup (/business/register)" do
    test "full flow: data, WhatsApp code, confirmation and success screen", %{conn: conn} do
      segment = Fixtures.restaurants()
      Fixtures.category()
      Fixtures.neighborhood()

      {:ok, view, html} = live(Fixtures.sign_in_business(conn), ~p"/business/register")
      assert html =~ "Passo 1 de 3"

      # Restaurant type shows the cuisine type field
      refute has_element?(view, "#signup-form select[name='signup[category_id]']")

      view
      |> element("#signup-form")
      |> render_change(%{"signup" => %{"segment_id" => segment.id}})

      assert has_element?(view, "#signup-form select[name='signup[category_id]']")

      params =
        Fixtures.signup_params(%{"whatsapp" => "(31) 97777-1234", "name" => "Cantina da Esquina"})

      view |> form("#signup-form", signup: params) |> render_submit()

      assert has_element?(view, "#code-form")
      assert render(view) =~ "1234"

      [message] = Fake.sent_to("+5531977771234")
      code = message.params["code"]

      view |> form("#code-form", code: %{code: "000000"}) |> render_submit()
      assert render(view) =~ "Código incorreto"

      view |> form("#code-form", code: %{code: code}) |> render_submit()

      assert has_element?(view, "#signup-done")
      assert render(view) =~ "Em análise, até 1 dia útil"
    end

    test "validation errors appear on the form", %{conn: conn} do
      segment = Fixtures.restaurants()
      Fixtures.category()
      Fixtures.neighborhood()
      {:ok, view, _html} = live(Fixtures.sign_in_business(conn), ~p"/business/register")

      # As in real use: picks the type first, so the cuisine field appears
      view
      |> element("#signup-form")
      |> render_change(%{"signup" => %{"segment_id" => segment.id}})

      view
      |> form("#signup-form",
        signup: Fixtures.signup_params(%{"whatsapp" => "123", "name" => "ab"})
      )
      |> render_submit()

      assert has_element?(view, "#signup-form", "use um WhatsApp brasileiro com DDD")
      assert has_element?(view, "#signup-form", "use entre 3 e 60 caracteres")
    end
  end

  defp from_place(place) do
    import Ecto.Query
    from(p in Place, where: p.id == ^place.id)
  end
end
