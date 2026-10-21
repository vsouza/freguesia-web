defmodule FreguesiaWeb.BusinessTest do
  use FreguesiaWeb.ConnCase, async: true

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Freguesia.{Business, DeliveryAreas, Fixtures}
  alias Freguesia.Catalog.PlaceCoverage
  alias Freguesia.Repo

  describe "sign-in" do
    test "the dev sign-in form creates the account and opens the account page", %{conn: conn} do
      conn = post(conn, ~p"/business/session", %{"email" => "nova@exemplo.test"})

      assert redirected_to(conn) == "/business/account"
      assert get_session(conn, "business_account_id")
      assert {:ok, account} = Business.sign_in("fake:nova@exemplo.test")
      assert account.email == "nova@exemplo.test"
    end

    test "a token that cannot be verified is refused and nothing is stored", %{conn: conn} do
      conn = post(conn, ~p"/business/session", %{"id_token" => "not-a-token"})

      assert redirected_to(conn) == "/business/sign-in"
      refute get_session(conn, "business_account_id")
    end

    test "a disabled account cannot sign in", %{conn: conn} do
      # The Fake derives the uid from the e-mail, so the disabled row carries the same uid.
      account =
        Fixtures.business_account(%{
          firebase_uid: "fake-parado@exemplo.test",
          email: "parado@exemplo.test"
        })

      Repo.update_all(from(a in Freguesia.Business.Account, where: a.id == ^account.id),
        set: [disabled_at: DateTime.utc_now() |> DateTime.truncate(:second)]
      )

      conn = post(conn, ~p"/business/session", %{"email" => "parado@exemplo.test"})

      assert redirected_to(conn) == "/business/sign-in"
      refute get_session(conn, "business_account_id")
    end

    test "sign-out ends the session: the account page asks to sign in again", %{conn: conn} do
      signed_in = Fixtures.sign_in_business(conn)
      out = delete(signed_in, ~p"/business/session")

      assert redirected_to(out) == "/"

      assert {:error, {:redirect, %{to: "/business/sign-in"}}} =
               live(recycle(out), ~p"/business/account")
    end
  end

  describe "signed-in areas" do
    test "anonymous visitors are sent to sign-in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/business/sign-in"}}} = live(conn, ~p"/business/account")

      assert {:error, {:redirect, %{to: "/business/sign-in"}}} =
               live(conn, ~p"/business/register")
    end

    test "the account page lists only the places the account manages", %{conn: conn} do
      account = Fixtures.business_account()
      mine = Fixtures.verified_place(%{name: "Minha Pizzaria"})
      theirs = Fixtures.verified_place(%{name: "Pizzaria Alheia"})
      Business.add_owner(account.id, mine.id)

      {:ok, view, _html} = live(Fixtures.sign_in_business(conn, account), ~p"/business/account")

      assert has_element?(view, "#business-place-#{mine.id}")
      refute has_element?(view, "#business-place-#{theirs.id}")
    end

    test "a place outside the account cannot open its delivery area", %{conn: conn} do
      other = Fixtures.verified_place(%{name: "Outra Casa"})

      assert {:error, {:live_redirect, %{to: "/business/account"}}} =
               live(
                 Fixtures.sign_in_business(conn),
                 ~p"/business/places/#{other.id}/delivery-area"
               )
    end

    test "saving a smaller radius and removing a neighborhood updates the coverage", %{
      conn: conn
    } do
      account = Fixtures.business_account()
      place = Fixtures.verified_place(%{name: "Area Certa"})
      Business.add_owner(account.id, place.id)

      {:ok, view, _html} =
        live(
          Fixtures.sign_in_business(conn, account),
          ~p"/business/places/#{place.id}/delivery-area"
        )

      assert has_element?(view, "#neighborhood-#{place.neighborhood.slug}")

      view
      |> form("#delivery-area-form", area: %{"radius_km" => "1.0", "included" => []})
      |> render_submit()

      area = DeliveryAreas.get_for_place(place.id)
      assert area.radius_m == 1000
      assert [_] = area.exclusions
      refute Repo.exists?(from c in PlaceCoverage, where: c.place_id == ^place.id)
    end

    test "the owner moves the point to where they stand, and distances follow", %{conn: conn} do
      account = Fixtures.business_account()
      place = Fixtures.verified_place(%{name: "Ponto do Dono"})
      Business.add_owner(account.id, place.id)

      {:ok, view, html} =
        live(
          Fixtures.sign_in_business(conn, account),
          ~p"/business/places/#{place.id}/delivery-area"
        )

      assert html =~ "Ponto atual:"

      render_hook(view, "set_point", %{"lat" => -19.938, "lng" => -43.939})

      assert has_element?(view, "#point-status", "-19.93800, -43.93900")
      assert render(view) =~ "Localização salva"
    end

    test "a location outside the pilot is refused with a message", %{conn: conn} do
      account = Fixtures.business_account()
      place = Fixtures.verified_place(%{name: "Fora do Piloto"})
      Business.add_owner(account.id, place.id)

      {:ok, view, _html} =
        live(
          Fixtures.sign_in_business(conn, account),
          ~p"/business/places/#{place.id}/delivery-area"
        )

      html = render_hook(view, "set_point", %{"lat" => -20.5, "lng" => -44.5})
      assert html =~ "fora dos bairros do piloto"
    end

    test "a radius outside the allowed range is refused and nothing changes", %{conn: conn} do
      account = Fixtures.business_account()
      place = Fixtures.verified_place(%{name: "Raio Errado"})
      Business.add_owner(account.id, place.id)
      before = DeliveryAreas.get_for_place(place.id).radius_m

      {:ok, view, _html} =
        live(
          Fixtures.sign_in_business(conn, account),
          ~p"/business/places/#{place.id}/delivery-area"
        )

      view
      |> form("#delivery-area-form", area: %{"radius_km" => "9.0", "included" => []})
      |> render_submit()

      assert DeliveryAreas.get_for_place(place.id).radius_m == before
    end
  end
end
