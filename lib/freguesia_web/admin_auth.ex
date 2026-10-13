defmodule FreguesiaWeb.AdminAuth do
  @moduledoc """
  Backoffice protection (PRD §7 and §13).

  8-hour session, operator reloaded from the database on every request: if the
  operator is removed, the next request already kicks them out.
  """
  use FreguesiaWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Freguesia.Admin

  @doc "Plug: loads the session operator into `conn.assigns.operator`, if any."
  def fetch_current_operator(conn, _opts) do
    operator = conn |> get_session() |> Admin.fetch_session_operator()
    assign(conn, :operator, operator)
  end

  @doc "Plug: requires a logged-in operator. Without a session, redirects to login."
  def require_operator(conn, _opts) do
    if conn.assigns[:operator] do
      conn
    else
      conn
      |> redirect(to: ~p"/admin/sign-in")
      |> halt()
    end
  end

  @doc "Stores the session of the already authenticated operator (password + 2FA)."
  def log_in(conn, operator) do
    conn
    |> configure_session(renew: true)
    |> delete_session(:pending_operator_id)
    |> put_session(:operator_id, operator.id)
    |> put_session(:operator_at, System.system_time(:second))
  end

  @doc "on_mount for the backoffice LiveViews."
  def on_mount(:require_operator, _params, session, socket) do
    case Admin.fetch_session_operator(session) do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin/sign-in")}

      operator ->
        {:cont, Phoenix.Component.assign(socket, :operator, operator)}
    end
  end
end
