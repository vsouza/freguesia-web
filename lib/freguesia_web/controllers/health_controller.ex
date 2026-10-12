defmodule FreguesiaWeb.HealthController do
  @moduledoc "Liveness for deploys (PRD §14). `/health/deep` comes in phase 1."
  use FreguesiaWeb, :controller

  def index(conn, _params) do
    send_resp(conn, 200, "ok")
  end
end
