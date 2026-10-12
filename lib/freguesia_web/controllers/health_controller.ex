defmodule FreguesiaWeb.HealthController do
  @moduledoc "Liveness para o deploy (PRD §14). `/health/deep` vem na fase 1."
  use FreguesiaWeb, :controller

  def index(conn, _params) do
    send_resp(conn, 200, "ok")
  end
end
