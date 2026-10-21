defmodule FreguesiaWeb.G1Test do
  @moduledoc """
  G1 gate of Phase 0 (PRD §16): signup → code (fake) → approval → card live.

  Runs end to end on the server with LiveViewTest. The PRD asks for Wallaby in the browser
  real; that waits until chromedriver is in CI.
  """
  use FreguesiaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Freguesia.{Admin, Fixtures, Messaging.Fake, Repo}
  alias Freguesia.Admin.Operator

  test "signup → code → approval → card appears in the neighborhood", %{conn: conn} do
    Fixtures.restaurants()
    Fixtures.category()
    Fixtures.neighborhood()

    # 1. Restaurant signs up and confirms the code
    whatsapp = Fixtures.unique_whatsapp()
    e164 = "+55" <> String.replace(whatsapp, ~r/\D/, "")

    {:ok, signup, _} = live(Fixtures.sign_in_business(conn), ~p"/business/register")

    signup
    |> element("#signup-form")
    |> render_change(%{"signup" => %{"segment_id" => Fixtures.restaurants().id}})

    params = Fixtures.signup_params(%{"name" => "Pizzaria G1", "whatsapp" => whatsapp})
    signup |> form("#signup-form", signup: params) |> render_submit()

    [%{params: %{"code" => code}}] = Fake.sent_to(e164)
    signup |> form("#code-form", code: %{code: code}) |> render_submit()
    assert has_element?(signup, "#signup-done")

    # 2. Before approval, the place does not appear in the catalog
    {:ok, _home, html} = live(build_conn(), ~p"/areas/savassi")
    refute html =~ "Pizzaria G1"

    # 3. Operator logs into the backoffice and approves
    operator = Fixtures.operator()
    {:ok, operator, _} = Admin.start_totp_enrollment(operator)

    {:ok, _} =
      Admin.confirm_totp_enrollment(operator, NimbleTOTP.verification_code(operator.totp_secret))

    admin =
      post(build_conn(), ~p"/admin/sign-in", %{
        "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
      })

    admin =
      post(admin, ~p"/admin/sign-in/code", %{
        "totp" => %{"code" => NimbleTOTP.verification_code(operator.totp_secret)}
      })

    assert redirected_to(admin) == ~p"/admin/verifications"

    {:ok, queue, _} = live(admin, ~p"/admin/verifications")
    assert has_element?(queue, "#requests", "Pizzaria G1")

    request = Repo.one!(from_request(e164))
    {:ok, detail, _} = live(admin, ~p"/admin/verifications/#{request.id}")

    # WhatsApp profile name not read yet: approval requires an internal note
    assert {:error, {:live_redirect, _}} =
             detail
             |> form("#approve-form", decision: %{note: "Nome conferido com o restaurante"})
             |> render_submit()

    # 4. The approval message goes out with the page link
    assert [approval] = Enum.filter(Fake.sent_to(e164), &(&1.template == "place_approved"))
    assert approval.params["url"] =~ "/places/pizzaria-g1"

    # 5. The card is live, with the Verified badge
    {:ok, home, _} = live(build_conn(), ~p"/areas/savassi")
    assert has_element?(home, "#place-card-pizzaria-g1", "Pizzaria G1")
    assert has_element?(home, "#place-card-pizzaria-g1", "Verificado")

    # 6. And the details page has the order-on-WhatsApp button
    {:ok, place, _} = live(build_conn(), ~p"/places/pizzaria-g1")
    assert has_element?(place, "a#whatsapp-cta[href='/places/pizzaria-g1/whatsapp']")

    # ...and the click records the opening and leads to the restaurant's wa.me link
    redirected = build_conn() |> get("/places/pizzaria-g1/whatsapp")
    assert redirected_to(redirected, 302) =~ "https://wa.me/" <> String.replace(e164, "+", "")

    # The test operator ends up with confirmed 2FA
    assert Repo.get!(Operator, operator.id).totp_confirmed_at
  end

  defp from_request(e164) do
    import Ecto.Query

    from r in Freguesia.Verification.Request,
      join: p in assoc(r, :place),
      where: p.whatsapp_e164 == ^e164
  end
end
