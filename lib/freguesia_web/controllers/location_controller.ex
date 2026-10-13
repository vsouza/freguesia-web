defmodule FreguesiaWeb.LocationController do
  @moduledoc """
  `GET /location/:neighborhood`: remembers the chosen pilot neighborhood for this
  session and opens its home. Used after the browser geolocation was resolved
  on the server, and for manual choices. No coordinates reach this controller.
  """
  use FreguesiaWeb, :controller

  alias Freguesia.{Catalog, Events}

  def set(conn, %{"neighborhood" => slug} = params) do
    case Catalog.get_pilot_neighborhood_by_slug(slug) do
      nil ->
        conn
        |> put_flash(:error, gettext("We only operate in the pilot neighborhoods so far."))
        |> redirect(to: ~p"/location")

      neighborhood ->
        event = if params["via"] == "geo", do: "location_granted", else: "location_manual"
        Events.track(event, %{neighborhood: neighborhood.slug}, conn.assigns[:device_id])

        conn
        |> put_session("neighborhood", neighborhood.slug)
        |> redirect(to: ~p"/areas/#{neighborhood.slug}")
    end
  end
end
