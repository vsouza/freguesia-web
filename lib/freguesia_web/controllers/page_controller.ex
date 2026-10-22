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

  # "How it works": three steps, same wording as the welcome screen.
  def how_it_works(conn, _params) do
    render(conn, :how_it_works,
      page_title: gettext("How it works"),
      current_neighborhood: neighborhood(conn)
    )
  end

  # Profile tab. Customer accounts are not in the pilot yet; the screen says so.
  def profile(conn, _params) do
    render(conn, :profile,
      page_title: gettext("Profile"),
      current_neighborhood: neighborhood(conn)
    )
  end

  defp neighborhood(conn), do: get_session(conn, "neighborhood") || @default_neighborhood
end
