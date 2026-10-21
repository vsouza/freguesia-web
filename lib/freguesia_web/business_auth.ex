defmodule FreguesiaWeb.BusinessAuth do
  @moduledoc """
  Business account session (PRD §6). The sign-in controller stores the account id in the
  session after verifying the Firebase ID token. Later requests only read that id.

  - `fetch_current_business_account/2`: plug, assigns `current_business_account` or `nil`.
  - `require_business_account/2`: plug, sends anonymous visitors to the sign-in page.
  - `on_mount(:require, ...)`: the same check for LiveViews.
  """
  use Phoenix.VerifiedRoutes,
    endpoint: FreguesiaWeb.Endpoint,
    router: FreguesiaWeb.Router,
    statics: FreguesiaWeb.static_paths()

  use Gettext, backend: FreguesiaWeb.Gettext

  import Plug.Conn
  import Phoenix.Controller

  alias Freguesia.Business

  def fetch_current_business_account(conn, _opts) do
    account =
      case get_session(conn, :business_account_id) do
        nil -> nil
        id -> Business.get_account(id)
      end

    assign(conn, :current_business_account, account)
  end

  def require_business_account(conn, _opts) do
    if conn.assigns[:current_business_account] do
      conn
    else
      conn
      |> put_flash(:error, gettext("Sign in to manage your place."))
      |> redirect(to: ~p"/business/sign-in")
      |> halt()
    end
  end

  def on_mount(:require, _params, session, socket) do
    account =
      case session["business_account_id"] do
        nil -> nil
        id -> Business.get_account(id)
      end

    if account do
      {:cont, Phoenix.Component.assign(socket, :current_business_account, account)}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, gettext("Sign in to manage your place."))
       |> Phoenix.LiveView.redirect(to: ~p"/business/sign-in")}
    end
  end
end
