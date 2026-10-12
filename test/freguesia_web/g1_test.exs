defmodule FreguesiaWeb.G1Test do
  @moduledoc """
  Portão G1 da Fase 0 (PRD §16): cadastro → código (fake) → aprovação → card no ar.

  Roda ponta a ponta no servidor com LiveViewTest. O PRD pede Wallaby no navegador
  real; isso fica para quando o chromedriver estiver no CI.
  """
  use FreguesiaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Freguesia.{Admin, Fixtures, Messaging.Fake, Repo}
  alias Freguesia.Admin.Operator

  test "cadastro → código → aprovação → card aparece no bairro", %{conn: conn} do
    Fixtures.restaurants()
    Fixtures.category()
    Fixtures.neighborhood()

    # 1. Restaurante faz o cadastro e confirma o código
    whatsapp = Fixtures.unique_whatsapp()
    e164 = "+55" <> String.replace(whatsapp, ~r/\D/, "")

    {:ok, signup, _} = live(conn, ~p"/cadastrar")

    signup
    |> element("#signup-form")
    |> render_change(%{"signup" => %{"segment_id" => Fixtures.restaurants().id}})

    params = Fixtures.signup_params(%{"name" => "Pizzaria G1", "whatsapp" => whatsapp})
    signup |> form("#signup-form", signup: params) |> render_submit()

    [%{params: %{"code" => code}}] = Fake.sent_to(e164)
    signup |> form("#code-form", code: %{code: code}) |> render_submit()
    assert has_element?(signup, "#signup-done")

    # 2. Antes da aprovação, o lugar não aparece no catálogo
    {:ok, _home, html} = live(build_conn(), ~p"/bairro/savassi")
    refute html =~ "Pizzaria G1"

    # 3. Operador entra no backoffice e aprova
    operator = Fixtures.operator()
    {:ok, operator, _} = Admin.start_totp_enrollment(operator)

    {:ok, _} =
      Admin.confirm_totp_enrollment(operator, NimbleTOTP.verification_code(operator.totp_secret))

    admin =
      post(build_conn(), ~p"/admin/entrar", %{
        "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
      })

    admin =
      post(admin, ~p"/admin/entrar/codigo", %{
        "totp" => %{"code" => NimbleTOTP.verification_code(operator.totp_secret)}
      })

    assert redirected_to(admin) == ~p"/admin/verificacoes"

    {:ok, queue, _} = live(admin, ~p"/admin/verificacoes")
    assert has_element?(queue, "#requests", "Pizzaria G1")

    request = Repo.one!(from_request(e164))
    {:ok, detail, _} = live(admin, ~p"/admin/verificacoes/#{request.id}")

    # Nome do perfil WhatsApp ainda não foi lido: a aprovação pede nota interna
    assert {:error, {:live_redirect, _}} =
             detail
             |> form("#approve-form", decision: %{note: "Nome conferido com o restaurante"})
             |> render_submit()

    # 4. A mensagem de aprovação sai com o link da página
    assert [approval] = Enum.filter(Fake.sent_to(e164), &(&1.template == "lugar_aprovado"))
    assert approval.params["url"] =~ "/lugar/pizzaria-g1"

    # 5. O card está no ar, com o selo Verificado
    {:ok, home, _} = live(build_conn(), ~p"/bairro/savassi")
    assert has_element?(home, "#place-card-pizzaria-g1", "Pizzaria G1")
    assert has_element?(home, "#place-card-pizzaria-g1", "Verificado")

    # 6. E a página de detalhes tem o botão de pedir no WhatsApp
    {:ok, place, _} = live(build_conn(), ~p"/lugar/pizzaria-g1")
    assert has_element?(place, "a#whatsapp-cta[href='/r/pizzaria-g1']")

    # ...e o clique registra a abertura e leva ao wa.me do restaurante
    redirected = build_conn() |> get("/r/pizzaria-g1")
    assert redirected_to(redirected, 302) =~ "https://wa.me/" <> String.replace(e164, "+", "")

    # O operador de teste ficou com 2FA confirmado
    assert Repo.get!(Operator, operator.id).totp_confirmed_at
  end

  defp from_request(e164) do
    import Ecto.Query

    from r in Freguesia.Verification.Request,
      join: p in assoc(r, :place),
      where: p.whatsapp_e164 == ^e164
  end
end
