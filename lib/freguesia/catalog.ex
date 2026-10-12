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
  def list_home_places(neighborhood, now \\ DateTime.utc_now()) do
    neighborhood_id = neighborhood.id

    coverage =
      from c in PlaceCoverage, where: c.neighborhood_id == ^neighborhood_id, select: c.place_id

    places =
      Repo.all(
        from p in Place,
          where: p.status == :verified,
          where: p.neighborhood_id == ^neighborhood_id or p.id in subquery(coverage),
          preload: [
            :segment,
            :category,
            :neighborhood,
            offers: ^approved_offers_query(),
            stats: ^from(s in PlaceStat, where: s.window in ["30d", "90d"])
          ]
      )

    places
    |> Enum.map(&with_hours_status(&1, now))
    |> Enum.sort_by(fn place ->
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
