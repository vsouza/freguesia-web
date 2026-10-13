defmodule Freguesia.Catalog do
  @moduledoc """
  Catalog reads: pilot neighborhoods, segments, places and a neighborhood home
  (PRD §5 and §8).
  """
  import Ecto.Query, warn: false

  alias Freguesia.Catalog.{Neighborhood, Offer, OpeningHours, Place, PlaceCoverage, Segment, Text}
  alias Freguesia.Repo
  alias Freguesia.Reports.{PlaceStat, Stats}

  @doc "Pilot neighborhoods, in alphabetical order."
  def list_pilot_neighborhoods do
    Repo.all(from n in Neighborhood, where: n.pilot == true, order_by: n.name)
  end

  def get_pilot_neighborhood_by_slug(slug) do
    Repo.one(from n in Neighborhood, where: n.slug == ^slug and n.pilot == true)
  end

  @doc "Segments with their categories, for signup."
  def list_segments do
    Repo.all(
      from s in Segment,
        order_by: s.name,
        preload: [categories: ^from(c in Freguesia.Catalog.Category, order_by: c.name)]
    )
  end

  def get_segment_by_key(key), do: Repo.get_by(Segment, key: key)

  @doc """
  Verified places that serve the neighborhood, in home order (PRD §8):
  open ones before closed ones, then by name. Ads and promotions are not included here.

  Each place comes with `hours_status` filled in and its approved offer (if any).
  """
  def list_home_places(neighborhood, now \\ DateTime.utc_now(), filters \\ %{}) do
    neighborhood_id = neighborhood.id

    coverage =
      from c in PlaceCoverage, where: c.neighborhood_id == ^neighborhood_id, select: c.place_id

    verified_places_query()
    |> where([p], p.neighborhood_id == ^neighborhood_id or p.id in subquery(coverage))
    |> Repo.all()
    |> Enum.map(&with_hours_status(&1, now))
    |> Enum.filter(&matches_filters?(&1, filters))
    |> sort_places()
  end

  @doc """
  Verified places whose name contains `query` (accent-insensitive), across the pilot.
  Used by the search screen.
  """
  def search_places(query, now \\ DateTime.utc_now()) do
    verified_places_query()
    |> Repo.all()
    |> Enum.map(&with_hours_status(&1, now))
    |> Enum.filter(&matches_filters?(&1, %{query: query}))
    |> sort_places()
  end

  @doc """
  Pilot neighborhood that contains a point (longitude, latitude), or `nil`.
  Uses PostGIS `ST_Contains`. The coordinates are never stored.
  """
  def pilot_neighborhood_at(lat, lng) when is_number(lat) and is_number(lng) do
    # Schemaless query: the geometry is referenced by column name, so the alias
    # Ecto generates for the schema does not matter.
    Repo.one(
      from n in "neighborhoods",
        where:
          n.pilot == true and
            fragment(
              "ST_Contains(?, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
              n.geom,
              ^lng,
              ^lat
            ),
        select: %{id: n.id, slug: n.slug, name: n.name},
        limit: 1
    )
  end

  def pilot_neighborhood_at(_lat, _lng), do: nil

  defp verified_places_query do
    from p in Place,
      where: p.status == :verified,
      preload: [
        :segment,
        :category,
        :neighborhood,
        offers: ^approved_offers_query(),
        stats: ^from(s in PlaceStat, where: s.window in ["30d", "90d"])
      ]
  end

  # Filters from the home screen (PRD §5). Missing or blank filters match everything.
  defp matches_filters?(place, filters) do
    segment_match?(place, filters[:segment]) and category_match?(place, filters[:category]) and
      flags_match?(place, filters) and query_match?(place, filters[:query])
  end

  defp segment_match?(place, segment), do: blank?(segment) or place.segment.key == segment

  defp category_match?(place, category) do
    blank?(category) or (place.category != nil and place.category.key == category)
  end

  defp flags_match?(place, filters) do
    (!filters[:open] or match?({:open, _}, place.hours_status)) and
      (!filters[:perk] or active_offer(place) != nil) and
      (!filters[:verified] or place.status == :verified)
  end

  defp query_match?(place, query) do
    blank?(query) or String.contains?(Text.normalize(place.name), Text.normalize(query))
  end

  defp blank?(value), do: value in [nil, "", "all", false]

  defp sort_places(places) do
    Enum.sort_by(places, fn place ->
      {closed_rank(place.hours_status), -worked_30d(place), Text.normalize(place.name)}
    end)
  end

  @doc "Place by slug, with its approved offer and opening status. `nil` if it does not exist."
  def get_place_by_slug(slug, now \\ DateTime.utc_now()) do
    Place
    |> preload([
      :segment,
      :category,
      :neighborhood,
      offers: ^approved_offers_query(),
      stats: ^from(s in PlaceStat, where: s.window in ["30d", "90d"])
    ])
    |> Repo.get_by(slug: slug)
    |> case do
      nil -> nil
      place -> with_hours_status(place, now)
    end
  end

  @doc "The place's approved offer, if any. Takes the place with `offers` preloaded."
  def active_offer(%Place{offers: offers}) when is_list(offers) do
    Enum.find(offers, &(&1.status == :approved))
  end

  def active_offer(_place), do: nil

  defp approved_offers_query do
    from o in Offer, where: o.status == :approved, order_by: [desc: o.approved_at]
  end

  defp with_hours_status(place, now) do
    %{place | hours_status: OpeningHours.status(place.opening_hours, place.paused_until, now)}
  end

  defp worked_30d(place), do: Stats.window(place, "30d").worked

  defp closed_rank({:open, _}), do: 0
  defp closed_rank({:paused}), do: 2
  defp closed_rank({:closed, _}), do: 1
end
