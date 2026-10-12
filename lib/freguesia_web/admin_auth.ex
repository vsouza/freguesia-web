defmodule FreguesiaWeb.AdminAuth do
  @moduledoc """
  Proteção do backoffice (PRD §7 e §13).

  Sessão de 8 horas, operador recarregado do banco a cada requisição: se o
  operador for removido, a próxima requisição já o derruba.
  """
  use FreguesiaWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Freguesia.Admin

  @doc "Plug: carrega o operador da sessão em `conn.assigns.operator`, se houver."
  def fetch_current_operator(conn, _opts) do
    operator = conn |> get_session() |> Admin.fetch_session_operator()
    assign(conn, :operator, operator)
  end

  @doc "Plug: exige operador logado. Sem sessão, manda para o login."
  def require_operator(conn, _opts) do
    if conn.assigns[:operator] do
      conn
    else
      conn
      |> redirect(to: ~p"/admin/entrar")
      |> halt()
    end
  end

  @doc "Grava a sessão do operador já autenticado (senha + 2FA)."
  def log_in(conn, operator) do
    conn
    |> configure_session(renew: true)
    |> delete_session(:pending_operator_id)
    |> put_session(:operator_id, operator.id)
    |> put_session(:operator_at, System.system_time(:second))
  end

  @doc "on_mount para as LiveViews do backoffice."
  def on_mount(:require_operator, _params, session, socket) do
    case Admin.fetch_session_operator(session) do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/admin/entrar")}

      operator ->
        {:cont, Phoenix.Component.assign(socket, :operator, operator)}
    end
  end
end
