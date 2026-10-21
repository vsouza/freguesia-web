defmodule FreguesiaWeb.AdsTest do
  use FreguesiaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Freguesia.{Admin, Business, Fixtures, Sponsorships}

  # Logs an operator in through the real sign-in and 2FA routes.
  defp logged_in(conn) do
    operator = Fixtures.operator()
    {:ok, operator, _uri} = Admin.start_totp_enrollment(operator)

    {:ok, operator} =
      Admin.confirm_totp_enrollment(operator, NimbleTOTP.verification_code(operator.totp_secret))

    conn =
      post(conn, ~p"/admin/sign-in", %{
        "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
      })

    conn =
      post(conn, ~p"/admin/sign-in/code", %{
        "totp" => %{"code" => NimbleTOTP.verification_code(operator.totp_secret)}
      })

    assert redirected_to(conn) == ~p"/admin/verifications"
    conn
  end

  test "a place's owner requests an own ad, and it waits for review", %{conn: conn} do
    account = Fixtures.business_account()
    place = Fixtures.verified_place(%{name: "Pede Anúncio"})
    Business.add_owner(account.id, place.id)

    {:ok, view, _html} =
      live(Fixtures.sign_in_business(conn, account), ~p"/business/places/#{place.id}/ad")

    view
    |> form("#ad-form", ad: %{"title" => "Sobremesa grátis", "body" => "", "days" => "2"})
    |> render_submit()

    assert render(view) =~ "Sobremesa grátis"
    assert has_element?(view, "#ad-requests")
    assert Sponsorships.own_detail_for(place.id) == nil
  end

  test "a place outside the account cannot request an ad", %{conn: conn} do
    other = Fixtures.verified_place(%{name: "Outra Casa"})

    assert {:error, {:live_redirect, %{to: "/business/account"}}} =
             live(Fixtures.sign_in_business(conn), ~p"/business/places/#{other.id}/ad")
  end

  test "the place page shows the own ad only after an operator approves it", %{conn: conn} do
    place = Fixtures.verified_place(%{name: "Com Anúncio Aprovado"})

    {:ok, sponsorship} =
      Sponsorships.request_own_ad(place, %{"title" => "Entrada grátis", "days" => "5"})

    html = conn |> get(~p"/places/#{place.slug}") |> html_response(200)
    refute html =~ ~s(id="own-ad")

    {:ok, :approved} = Sponsorships.approve(sponsorship.id, Fixtures.operator())

    {:ok, _view, html} = live(conn, ~p"/places/#{place.slug}")
    assert html =~ ~s(id="own-ad")
    assert html =~ "Entrada grátis"
    assert html =~ "Anúncio · pago pelo lugar"
  end

  test "the operator approves an ad from the backoffice queue", %{conn: conn} do
    place = Fixtures.verified_place(%{name: "Fila de Anúncios"})

    {:ok, sponsorship} =
      Sponsorships.request_own_ad(place, %{"title" => "Café em dobro", "days" => "1"})

    conn = logged_in(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/ads")

    assert has_element?(view, "#ad-#{sponsorship.id}")

    view |> element("#approve-ad-#{sponsorship.id}") |> render_click()

    assert has_element?(view, "#no-pending-ads")
    assert Sponsorships.own_detail_for(place.id)
  end

  test "the operator rejects an ad only with a reason", %{conn: conn} do
    place = Fixtures.verified_place(%{name: "Rejeitado"})

    {:ok, sponsorship} =
      Sponsorships.request_own_ad(place, %{"title" => "Preço baixo", "days" => "1"})

    conn = logged_in(conn)
    {:ok, view, _html} = live(conn, ~p"/admin/ads")

    view
    |> form("#reject-ad-form-#{sponsorship.id}", ad: %{"id" => sponsorship.id, "reason" => ""})
    |> render_submit()

    assert has_element?(view, "#ad-#{sponsorship.id}")

    view
    |> form("#reject-ad-form-#{sponsorship.id}",
      ad: %{"id" => sponsorship.id, "reason" => "Compara preço com app"}
    )
    |> render_submit()

    assert has_element?(view, "#no-pending-ads")
  end
end
