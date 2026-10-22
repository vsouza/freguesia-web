defmodule FreguesiaWeb.LocationController do
  @moduledoc """
  Location choices for the session (PRD §5 and §13).

  - `GET /location/:neighborhood`: a manual choice. Remembers the pilot neighborhood
    and forgets any browser point.
  - `POST /location/geo`: the browser point after geolocation. The coordinates come in
    the form body (never the URL), are rounded to about 100 m and kept in the session
    only. The database never sees them.
  """
  use FreguesiaWeb, :controller

  alias Freguesia.{Catalog, Events}

  def set(conn, %{"neighborhood" => slug}) do
    case Catalog.get_pilot_neighborhood_by_slug(slug) do
      nil ->
        not_pilot(conn)

      neighborhood ->
        Events.track(
          "location_manual",
          %{neighborhood: neighborhood.slug},
          conn.assigns[:device_id]
        )

        conn
        |> put_session("neighborhood", neighborhood.slug)
        |> delete_session("point")
        |> redirect(to: ~p"/areas/#{neighborhood.slug}")
    end
  end

  def geo(conn, %{"geo" => %{"neighborhood" => slug} = geo}) do
    case {Catalog.get_pilot_neighborhood_by_slug(slug), parse_point(geo)} do
      {nil, _} ->
        not_pilot(conn)

      {neighborhood, {:ok, point}} ->
        Events.track(
          "location_granted",
          %{neighborhood: neighborhood.slug},
          conn.assigns[:device_id]
        )

        conn
        |> put_session("neighborhood", neighborhood.slug)
        |> put_session("point", point)
        |> redirect(to: ~p"/areas/#{neighborhood.slug}")

      {neighborhood, :error} ->
        Events.track(
          "location_manual",
          %{neighborhood: neighborhood.slug},
          conn.assigns[:device_id]
        )

        conn
        |> put_session("neighborhood", neighborhood.slug)
        |> delete_session("point")
        |> redirect(to: ~p"/areas/#{neighborhood.slug}")
    end
  end

  def geo(conn, _params), do: not_pilot(conn)

  defp not_pilot(conn) do
    conn
    |> put_flash(:error, gettext("We only operate in the pilot neighborhoods so far."))
    |> redirect(to: ~p"/location")
  end

  # Rounded to 3 decimals (about 100 m), the precision PRD §8 uses for the home.
  defp parse_point(%{"lat" => lat, "lng" => lng}) do
    with {lat, ""} <- Float.parse(lat),
         {lng, ""} <- Float.parse(lng),
         true <- lat >= -90 and lat <= 90 and lng >= -180 and lng <= 180 do
      {:ok, %{"lat" => Float.round(lat, 3), "lng" => Float.round(lng, 3)}}
    else
      _ -> :error
    end
  end

  defp parse_point(_), do: :error
end
