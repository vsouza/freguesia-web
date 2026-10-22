defmodule FreguesiaWeb.BusinessSessionController do
  @moduledoc """
  Business session (PRD §6). The sign-in page itself is `FreguesiaWeb.BusinessSignInLive`.

  `POST /business/session` receives the Firebase ID token from the browser, verifies it
  through `Freguesia.Business.sign_in/1` and stores the account id in the session.
  Sign-out drops the whole session.
  """
  use FreguesiaWeb, :controller

  alias Freguesia.Business

  def create(conn, %{"id_token" => token}), do: sign_in(conn, token)

  # Development only: the e-mail form turns into a Fake token. The Fake is not
  # configured in production, so this clause refuses there.
  def create(conn, %{"email" => email}) when is_binary(email) do
    if dev_sign_in?(),
      do: sign_in(conn, "fake:" <> email),
      else: sign_in_failed(conn)
  end

  def create(conn, _params), do: sign_in_failed(conn)

  defp sign_in(conn, token) do
    case Business.sign_in(token) do
      {:ok, account} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:business_account_id, account.id)
        |> redirect(to: ~p"/business/account")

      {:error, _reason} ->
        sign_in_failed(conn)
    end
  end

  defp sign_in_failed(conn) do
    conn
    |> put_flash(:error, gettext("We could not confirm your sign-in. Try again."))
    |> redirect(to: ~p"/business/sign-in")
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end

  # The e-mail "sign-in" only exists where the Fake identity is configured.
  defp dev_sign_in?, do: Business.dev_identity?()
end
