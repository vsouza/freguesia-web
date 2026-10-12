defmodule FreguesiaWeb.Admin.AdminFlowTest do
  use FreguesiaWeb.ConnCase, async: true

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest

  alias Freguesia.{Admin, Fixtures, Repo}
  alias Freguesia.Admin.Operator

  defp login_path, do: ~p"/admin/entrar"

  # Operador com 2FA já cadastrado: pula o enrolamento e faz o login completo.
  defp logged_in_conn(conn) do
    operator = Fixtures.operator()
    {:ok, operator, _uri} = Admin.start_totp_enrollment(operator)

    {:ok, operator} =
      Admin.confirm_totp_enrollment(operator, NimbleTOTP.verification_code(operator.totp_secret))

    conn =
      post(conn, login_path(), %{
        "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
      })

    assert redirected_to(conn) == ~p"/admin/entrar/codigo"

    conn =
      post(conn, ~p"/admin/entrar/codigo", %{
        "totp" => %{"code" => NimbleTOTP.verification_code(operator.totp_secret)}
      })

    assert redirected_to(conn) == ~p"/admin/verificacoes"
    {conn, operator}
  end

  defp pending_request! do
    place = Fixtures.verified_place(%{name: "Pedido Pendente"})

    Repo.update_all(from(p in Freguesia.Catalog.Place, where: p.id == ^place.id),
      set: [status: :pending]
    )

    Repo.insert!(%Freguesia.Verification.Request{
      place_id: place.id,
      status: :pending,
      checks: %{}
    })
  end

  describe "login" do
    test "senha errada volta ao formulário com erro", %{conn: conn} do
      operator = Fixtures.operator()

      conn =
        post(conn, login_path(), %{
          "operator" => %{"email" => operator.email, "password" => "errada-errada-errada"}
        })

      assert html_response(conn, 200) =~ "E-mail ou senha inválidos"
      assert get_session(conn, :operator_id) == nil
    end

    test "sem 2FA cadastrado, o primeiro login vai para o enrolamento com QR e chave", %{
      conn: conn
    } do
      operator = Fixtures.operator()

      conn =
        post(conn, login_path(), %{
          "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
        })

      assert redirected_to(conn) == ~p"/admin/entrar/cadastrar-2fa"

      html = conn |> recycle() |> get(~p"/admin/entrar/cadastrar-2fa") |> html_response(200)
      assert html =~ "totp-qr"
      assert html =~ "totp-secret"
    end

    test "código de enrolamento errado não entra; o certo confirma e entra", %{conn: conn} do
      operator = Fixtures.operator()

      conn =
        post(conn, login_path(), %{
          "operator" => %{"email" => operator.email, "password" => Fixtures.password()}
        })

      conn = conn |> recycle() |> get(~p"/admin/entrar/cadastrar-2fa")

      wrong =
        conn
        |> recycle()
        |> post(~p"/admin/entrar/cadastrar-2fa", %{"totp" => %{"code" => "000000"}})

      assert redirected_to(wrong) == ~p"/admin/entrar/cadastrar-2fa"

      secret = Repo.get!(Operator, operator.id).totp_secret
      code = NimbleTOTP.verification_code(secret)

      ok = recycle(wrong) |> post(~p"/admin/entrar/cadastrar-2fa", %{"totp" => %{"code" => code}})
      assert redirected_to(ok) == ~p"/admin/verificacoes"
      assert Repo.get!(Operator, operator.id).totp_confirmed_at
    end

    test "fila é protegida: sem login, redireciona para o formulário", %{conn: conn} do
      assert redirected_to(get(conn, ~p"/admin/verificacoes")) == login_path()
      assert {:error, {:redirect, %{to: "/admin/entrar"}}} = live(conn, ~p"/admin/verificacoes")
    end

    test "logout encerra a sessão", %{conn: conn} do
      {conn, _operator} = logged_in_conn(conn)

      conn = delete(conn, ~p"/admin/sair")
      assert redirected_to(conn) == login_path()

      assert redirected_to(get(recycle(conn), ~p"/admin/verificacoes")) == login_path()
    end
  end

  describe "fila e decisões" do
    test "lista o pedido pendente e abre a análise", %{conn: conn} do
      request = pending_request!()
      {conn, _operator} = logged_in_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/admin/verificacoes")
      assert has_element?(view, "#requests", "Pedido Pendente")

      {:ok, detail, html} = live(conn, ~p"/admin/verificacoes/#{request.id}")
      assert html =~ "Checagens automáticas"
      assert has_element?(detail, "#check-code")
      assert has_element?(detail, "#check-in_pilot")

      # Abrir o pedido já o coloca em análise
      assert Repo.get!(Freguesia.Verification.Request, request.id).status == :in_review
    end

    test "aprovar sem nota quando o nome do perfil não foi lido mostra o motivo", %{conn: conn} do
      request = pending_request!()
      {conn, _operator} = logged_in_conn(conn)
      {:ok, detail, _} = live(conn, ~p"/admin/verificacoes/#{request.id}")

      html = detail |> form("#approve-form", decision: %{note: ""}) |> render_submit()
      assert html =~ "Uma checagem não passou"
      assert Repo.get!(Freguesia.Verification.Request, request.id).status == :in_review
    end

    test "aprovar com nota publica o lugar e volta para a fila", %{conn: conn} do
      request = pending_request!()
      {conn, _operator} = logged_in_conn(conn)
      {:ok, detail, _} = live(conn, ~p"/admin/verificacoes/#{request.id}")

      result =
        detail
        |> form("#approve-form", decision: %{note: "Perfil conferido por telefone"})
        |> render_submit()

      assert {:ok, _queue, html} = follow_redirect(result, conn)
      assert html =~ "Lugar aprovado e publicado."
      assert Repo.get!(Freguesia.Verification.Request, request.id).status == :approved
    end

    test "pedir ajuste sem motivo não envia nada; com motivo, envia", %{conn: conn} do
      request = pending_request!()
      {conn, _operator} = logged_in_conn(conn)
      {:ok, detail, _} = live(conn, ~p"/admin/verificacoes/#{request.id}")

      html = detail |> form("#changes-form", decision: %{reason: "  "}) |> render_submit()
      assert html =~ "Escreva o motivo para continuar"

      assert {:error, {:live_redirect, _}} =
               detail
               |> form("#changes-form", decision: %{reason: "Envie uma foto da fachada"})
               |> render_submit()

      assert Repo.get!(Freguesia.Verification.Request, request.id).status == :needs_changes
    end

    test "recusar exige motivo", %{conn: conn} do
      request = pending_request!()
      {conn, _operator} = logged_in_conn(conn)
      {:ok, detail, _} = live(conn, ~p"/admin/verificacoes/#{request.id}")

      result =
        detail
        |> form("#reject-form", decision: %{reason: "Número de cliente, não de restaurante"})
        |> render_submit()

      assert {:ok, _queue, html} = follow_redirect(result, conn)
      assert html =~ "Cadastro recusado."
      assert Repo.get!(Freguesia.Verification.Request, request.id).status == :rejected
    end

    test "pedido inexistente volta para a fila", %{conn: conn} do
      {conn, _operator} = logged_in_conn(conn)

      assert {:error, {:live_redirect, %{to: "/admin/verificacoes"}}} =
               live(conn, ~p"/admin/verificacoes/#{Ecto.UUID.generate()}")
    end
  end
end
