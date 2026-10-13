defmodule FreguesiaWeb.Admin.SessionController do
  @moduledoc """
  Backoffice login in three steps: email and password, then the app code
  (TOTP). On first access, the operator registers the app before signing in.
  """
  use FreguesiaWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Freguesia.Admin
  alias FreguesiaWeb.AdminAuth

  def index(conn, _params) do
    if conn.assigns[:operator] do
      redirect(conn, to: ~p"/admin/verifications")
    else
      redirect(conn, to: ~p"/admin/sign-in")
    end
  end

  def new(conn, _params) do
    if conn.assigns[:operator] do
      redirect(conn, to: ~p"/admin/verifications")
    else
      render(conn, :new, form: login_form(), page_title: gettext("Log in"))
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
        |> put_flash(:error, gettext("Invalid email or password."))
        |> render(:new, form: login_form(email), page_title: gettext("Log in"))
    end
  end

  def totp(conn, _params) do
    case pending_operator(conn) do
      nil -> redirect(conn, to: ~p"/admin/sign-in")
      _operator -> render(conn, :totp, form: totp_form(), page_title: gettext("Code"))
    end
  end

  def verify_totp(conn, %{"totp" => %{"code" => code}}) do
    with operator when not is_nil(operator) <- pending_operator(conn),
         {:ok, operator} <- Admin.verify_totp(operator, String.trim(code)) do
      conn
      |> AdminAuth.log_in(operator)
      |> redirect(to: ~p"/admin/verifications")
    else
      nil ->
        redirect(conn, to: ~p"/admin/sign-in")

      {:error, _reason} ->
        conn
        |> put_flash(:error, gettext("Invalid code. Check the app and try again."))
        |> render(:totp, form: totp_form(), page_title: gettext("Code"))
    end
  end

  def enroll(conn, _params) do
    case pending_operator(conn) do
      nil ->
        redirect(conn, to: ~p"/admin/sign-in")

      operator ->
        {:ok, operator, uri} = Admin.start_totp_enrollment(operator)

        render(conn, :enroll,
          qr_svg: uri |> EQRCode.encode() |> EQRCode.svg(width: 220),
          secret: Base.encode32(operator.totp_secret, padding: false),
          form: totp_form(),
          page_title: gettext("Set up the app")
        )
    end
  end

  def confirm_enroll(conn, %{"totp" => %{"code" => code}}) do
    case pending_operator(conn) do
      nil ->
        redirect(conn, to: ~p"/admin/sign-in")

      operator ->
        case Admin.confirm_totp_enrollment(operator, String.trim(code)) do
          {:ok, operator} ->
            conn
            |> AdminAuth.log_in(operator)
            |> put_flash(
              :info,
              gettext("Done. From now on the app code is required on every login.")
            )
            |> redirect(to: ~p"/admin/verifications")

          {:error, _reason} ->
            conn
            |> put_flash(:error, gettext("Invalid code. Scan the QR code again if needed."))
            |> redirect(to: ~p"/admin/sign-in/2fa-setup")
        end
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, gettext("You have logged out of the backoffice."))
    |> redirect(to: ~p"/admin/sign-in")
  end

  defp next_step_after_password(%{totp_confirmed_at: nil}), do: ~p"/admin/sign-in/2fa-setup"
  defp next_step_after_password(_operator), do: ~p"/admin/sign-in/code"

  defp pending_operator(conn) do
    case get_session(conn, :pending_operator_id) do
      nil -> nil
      id -> Admin.get_operator(id)
    end
  end

  defp login_form(email \\ ""), do: to_form(%{"email" => email, "password" => ""}, as: :operator)
  defp totp_form, do: to_form(%{"code" => ""}, as: :totp)
end
