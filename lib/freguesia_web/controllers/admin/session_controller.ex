defmodule FreguesiaWeb.Admin.SessionController do
  @moduledoc """
  Login do backoffice em três passos: e-mail e senha, depois o código do app
  (TOTP). No primeiro acesso, o operador cadastra o app antes de entrar.
  """
  use FreguesiaWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Freguesia.Admin
  alias FreguesiaWeb.AdminAuth

  def index(conn, _params) do
    if conn.assigns[:operator] do
      redirect(conn, to: ~p"/admin/verificacoes")
    else
      redirect(conn, to: ~p"/admin/entrar")
    end
  end

  def new(conn, _params) do
    if conn.assigns[:operator] do
      redirect(conn, to: ~p"/admin/verificacoes")
    else
      render(conn, :new, form: login_form(), page_title: "Entrar")
    end
  end

  def create(conn, %{"operator" => %{"email" => email, "password" => password}}) do
    case Admin.authenticate(email, password) do
      {:ok, operator} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:pending_operator_id, operator.id)
        |> redirect(to: next_step_after_password(operator))

      {:error, :invalid} ->
        conn
        |> put_flash(:error, "E-mail ou senha inválidos.")
        |> render(:new, form: login_form(email), page_title: "Entrar")
    end
  end

  def totp(conn, _params) do
    case pending_operator(conn) do
      nil -> redirect(conn, to: ~p"/admin/entrar")
      _operator -> render(conn, :totp, form: totp_form(), page_title: "Código")
    end
  end

  def verify_totp(conn, %{"totp" => %{"code" => code}}) do
    with operator when not is_nil(operator) <- pending_operator(conn),
         {:ok, operator} <- Admin.verify_totp(operator, String.trim(code)) do
      conn
      |> AdminAuth.log_in(operator)
      |> redirect(to: ~p"/admin/verificacoes")
    else
      nil ->
        redirect(conn, to: ~p"/admin/entrar")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Código inválido. Confira o app e tente de novo.")
        |> render(:totp, form: totp_form(), page_title: "Código")
    end
  end

  def enroll(conn, _params) do
    case pending_operator(conn) do
      nil ->
        redirect(conn, to: ~p"/admin/entrar")

      operator ->
        {:ok, operator, uri} = Admin.start_totp_enrollment(operator)

        render(conn, :enroll,
          qr_svg: uri |> EQRCode.encode() |> EQRCode.svg(width: 220),
          secret: Base.encode32(operator.totp_secret, padding: false),
          form: totp_form(),
          page_title: "Cadastrar o app"
        )
    end
  end

  def confirm_enroll(conn, %{"totp" => %{"code" => code}}) do
    case pending_operator(conn) do
      nil ->
        redirect(conn, to: ~p"/admin/entrar")

      operator ->
        case Admin.confirm_totp_enrollment(operator, String.trim(code)) do
          {:ok, operator} ->
            conn
            |> AdminAuth.log_in(operator)
            |> put_flash(
              :info,
              "Pronto. A partir de agora o código do app é pedido em todo login."
            )
            |> redirect(to: ~p"/admin/verificacoes")

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Código inválido. Escaneie o QR de novo se preciso.")
            |> redirect(to: ~p"/admin/entrar/cadastrar-2fa")
        end
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Você saiu do backoffice.")
    |> redirect(to: ~p"/admin/entrar")
  end

  defp next_step_after_password(%{totp_confirmed_at: nil}), do: ~p"/admin/entrar/cadastrar-2fa"
  defp next_step_after_password(_operator), do: ~p"/admin/entrar/codigo"

  defp pending_operator(conn) do
    case get_session(conn, :pending_operator_id) do
      nil -> nil
      id -> Admin.get_operator(id)
    end
  end

  defp login_form(email \\ ""), do: to_form(%{"email" => email, "password" => ""}, as: :operator)
  defp totp_form, do: to_form(%{"code" => ""}, as: :totp)
end
