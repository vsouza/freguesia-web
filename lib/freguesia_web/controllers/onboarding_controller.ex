defmodule FreguesiaWeb.OnboardingController do
  @moduledoc "`GET /start`: marks the welcome screen as seen and moves on to location."
  use FreguesiaWeb, :controller

  alias Freguesia.Events

  def start(conn, _params) do
    Events.track("onboarding_started", %{}, conn.assigns[:device_id])

    conn
    |> put_resp_cookie("onboarded", "1",
      max_age: 365 * 24 * 60 * 60,
      same_site: "Lax",
      http_only: true
    )
    |> redirect(to: ~p"/location")
  end
end
