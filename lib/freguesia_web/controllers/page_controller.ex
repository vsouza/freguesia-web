defmodule FreguesiaWeb.PageController do
  use FreguesiaWeb, :controller

  @default_neighborhood "savassi"

  # Welcome screen on the first visit. A device that already saw it (cookie
  # `onboarded`) goes straight to its neighborhood (PRD §5).
  def home(conn, _params) do
    conn = fetch_cookies(conn)

    if conn.cookies["onboarded"] == "1" do
      redirect(conn, to: ~p"/areas/#{neighborhood(conn)}")
    else
      render(conn, :home, page_title: gettext("Welcome"))
    end
  end

  defp neighborhood(conn), do: get_session(conn, "neighborhood") || @default_neighborhood
end
