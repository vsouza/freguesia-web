defmodule FreguesiaWeb.Admin.SessionController do
  @moduledoc """
  Backoffice login in three steps: email and password, then the app code
  (TOTP). On first access, the operator registers the app before signing in.
  """
  use FreguesiaWeb, :controller

  import Phoenix.Component, only: [to_form: 2]

  alias Freguesia.{Admin, RateLimit}
  alias FreguesiaWeb.{AdminAuth, DeviceSession}

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
    with :ok <- RateLimit.check(:admin_password, client_keys(conn)),
         {:ok, operator} <- Admin.authenticate(email, password) do
      conn
      |> configure_session(renew: true)
      |> put_session(:pending_operator_id, operator.id)
      |> redirect(to: next_step_after_password(operator))
    else
      {:error, :rate_limited} ->
        rate_limited(conn, :admin_password, :new,
          form: login_form(email),
          page_title: gettext("Log in")
        )

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
         :ok <- check_totp_rate(conn, operator),
         {:ok, operator} <- Admin.verify_totp(operator, String.trim(code)) do
      conn
      |> AdminAuth.log_in(operator)
      |> redirect(to: ~p"/admin/verifications")
    else
      nil ->
        redirect(conn, to: ~p"/admin/sign-in")

      {:error, :rate_limited} ->
        rate_limited(conn, :admin_totp, :totp, form: totp_form(), page_title: gettext("Code"))

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
        render(conn, :enroll, enroll_assigns(operator))
    end
  end

  def confirm_enroll(conn, %{"totp" => %{"code" => code}}) do
    case pending_operator(conn) do
      nil -> redirect(conn, to: ~p"/admin/sign-in")
      operator -> confirm_enroll_code(conn, operator, String.trim(code))
    end
  end

  defp confirm_enroll_code(conn, operator, code) do
    with :ok <- check_totp_rate(conn, operator),
         {:ok, operator} <- Admin.confirm_totp_enrollment(operator, code) do
      conn
      |> AdminAuth.log_in(operator)
      |> put_flash(
        :info,
        gettext("Done. From now on the app code is required on every login.")
      )
      |> redirect(to: ~p"/admin/verifications")
    else
      {:error, :rate_limited} ->
        rate_limited(conn, :admin_totp, :enroll, enroll_assigns(operator))

      {:error, _reason} ->
        conn
        |> put_flash(:error, gettext("Invalid code. Scan the QR code again if needed."))
        |> redirect(to: ~p"/admin/sign-in/2fa-setup")
    end
  end

  # Reuses the secret not yet confirmed, so the QR code already scanned stays valid.
  defp enroll_assigns(operator) do
    {:ok, operator, uri} = Admin.start_totp_enrollment(operator)

    [
      qr_svg: uri |> EQRCode.encode() |> EQRCode.svg(width: 220),
      secret: Base.encode32(operator.totp_secret, padding: false),
      form: totp_form(),
      page_title: gettext("Set up the app")
    ]
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, gettext("You have logged out of the backoffice."))
    |> redirect(to: ~p"/admin/sign-in")
  end

  defp next_step_after_password(%{totp_confirmed_at: nil}), do: ~p"/admin/sign-in/2fa-setup"
  defp next_step_after_password(_operator), do: ~p"/admin/sign-in/code"

  # Rate limits (PRD §13), per device and IP. The password is not limited per email, so
  # failing from elsewhere cannot lock the operator out. The app code is also limited per
  # operator: past the password, it is only 6 digits.
  defp check_totp_rate(conn, operator),
    do: RateLimit.check(:admin_totp, [{:operator, operator.id} | client_keys(conn)])

  defp client_keys(conn), do: DeviceSession.rate_limit_keys(get_session(conn))

  defp rate_limited(conn, action, template, assigns) do
    message =
      gettext("Too many attempts. Wait %{minutes} minutes and try again.",
        minutes: RateLimit.window_minutes(action)
      )

    conn
    |> put_status(:too_many_requests)
    |> put_flash(:error, message)
    |> render(template, assigns)
  end

  defp pending_operator(conn) do
    case get_session(conn, :pending_operator_id) do
      nil -> nil
      id -> Admin.get_operator(id)
    end
  end

  defp login_form(email \\ ""), do: to_form(%{"email" => email, "password" => ""}, as: :operator)
  defp totp_form, do: to_form(%{"code" => ""}, as: :totp)
end
