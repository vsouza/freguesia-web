defmodule Freguesia.DeliveryAreas do
  @moduledoc """
  Delivery areas (PRD §6, §8 and §9).

  A place delivers within a radius around its point, minus the neighborhoods its
  owner removed. `place_coverage` (neighborhood → place) is derived from these rows
  and recomputed here, never edited by hand.

  The point is the place's `geom`. It starts as the centroid of its neighborhood
  (signup does not collect coordinates) and can be moved later.
  """
  import Ecto.Query, warn: false

  alias Freguesia.Catalog.{DeliveryArea, DeliveryAreaExclusion, PlaceCoverage}
  alias Freguesia.Repo

  @min_radius_m 500
  @max_radius_m 6000
  @step_m 500
  @default_radius_m 3000

  def radius_limits, do: {@min_radius_m, @max_radius_m, @step_m}
  def default_radius_m, do: @default_radius_m

  @doc "Delivery area of a place, with its exclusions, or `nil`."
  def get_for_place(place_id) do
    Repo.one(from a in DeliveryArea, where: a.place_id == ^place_id, preload: [:exclusions])
  end

  @doc """
  Called when a place is approved. Creates its area on first approval: a default
  radius around the point, with the in-radius neighborhoods the signup did not pick
  removed. An existing area is kept as it is. Coverage is recomputed either way.
  """
  def ensure_for_place(place_id, served_neighborhood_ids) do
    unless get_for_place(place_id), do: create_default(place_id, served_neighborhood_ids)

    recompute_coverage(place_id)
  end

  @doc """
  Saves the owner's area: radius in meters and the neighborhoods removed from it.
  Returns `{:ok, area}` or `{:error, changeset}`.
  """
  def save(place_id, radius_m, excluded_neighborhood_ids) do
    ensure_point(place_id)

    Repo.transact(fn ->
      changeset =
        DeliveryArea.changeset(%DeliveryArea{place_id: place_id}, %{radius_m: radius_m})

      with {:ok, area} <- upsert_area(changeset) do
        Repo.delete_all(from x in DeliveryAreaExclusion, where: x.delivery_area_id == ^area.id)
        insert_exclusions(area.id, excluded_neighborhood_ids)
        recompute_coverage(place_id)
        {:ok, Repo.preload(area, :exclusions, force: true)}
      end
    end)
  end

  @doc """
  Every pilot neighborhood with its distance in meters from the place's point, nearest
  first. The distance is `nil` when either geometry is missing.
  """
  def neighborhood_distances(place_id) do
    dumped = Ecto.UUID.dump!(place_id)

    Repo.all(
      from n in "neighborhoods",
        join: p in "places",
        on: p.id == ^dumped,
        where: n.pilot == true,
        order_by: [asc: fragment("ST_Distance(?::geography, ?::geography)", n.geom, p.geom)],
        select: %{
          id: type(n.id, Ecto.UUID),
          name: n.name,
          slug: n.slug,
          distance_m: fragment("ST_Distance(?::geography, ?::geography)", n.geom, p.geom)
        }
    )
    |> Enum.map(fn row -> %{row | distance_m: round_distance(row.distance_m)} end)
  end

  @doc """
  Moves the place's point to `(lat, lng)`, for example where the owner stands when
  saving the area. Only points inside a pilot neighborhood are accepted: the catalog
  does not cover anything else (PRD §5). Recomputes the derived coverage.
  """
  def set_point(place_id, lat, lng) when is_number(lat) and is_number(lng) do
    if Freguesia.Catalog.pilot_neighborhood_at(lat, lng) do
      Repo.query!(
        "UPDATE places SET geom = ST_SetSRID(ST_MakePoint($2, $3), 4326) WHERE id = $1",
        [Ecto.UUID.dump!(place_id), lng, lat]
      )

      recompute_coverage(place_id)
      {:ok, {lat, lng}}
    else
      {:error, :outside_pilot}
    end
  end

  def set_point(_place_id, _lat, _lng), do: {:error, :invalid_point}

  @doc "The place's point as `{lat, lng}`, or `nil` when it has none yet."
  def point_of(place_id) do
    dumped = Ecto.UUID.dump!(place_id)

    case Repo.one(
           from p in "places",
             where: p.id == ^dumped,
             select: {fragment("ST_Y(?)", p.geom), fragment("ST_X(?)", p.geom)}
         ) do
      {lat, lng} when is_number(lat) and is_number(lng) -> {lat, lng}
      _ -> nil
    end
  end

  @doc "How many neighborhoods the place covers right now (derived from the area)."
  def coverage_count(place_id) do
    Repo.aggregate(from(c in PlaceCoverage, where: c.place_id == ^place_id), :count)
  end

  @doc "Recomputes `place_coverage` for a place from its area. Idempotent."
  def recompute_coverage(place_id) do
    dumped = Ecto.UUID.dump!(place_id)

    Repo.delete_all(from c in PlaceCoverage, where: c.place_id == ^place_id)

    Repo.query!(
      """
      INSERT INTO place_coverage (place_id, neighborhood_id, inserted_at, updated_at)
      SELECT p.id, n.id, now(), now()
      FROM places p
      JOIN delivery_areas d ON d.place_id = p.id
      JOIN neighborhoods n ON n.pilot = true AND n.geom IS NOT NULL
      WHERE p.id = $1
        AND p.geom IS NOT NULL
        AND ST_DWithin(n.geom::geography, p.geom::geography, d.radius_m)
        AND NOT EXISTS (
          SELECT 1 FROM delivery_area_exclusions x
          WHERE x.delivery_area_id = d.id AND x.neighborhood_id = n.id
        )
      """,
      [dumped]
    )

    :ok
  end

  @doc """
  Place ids whose area covers the point `(lat, lng)` (PRD §8): the point is inside the
  radius and not inside a neighborhood the owner removed. Used as a subquery by the home.
  """
  def covering_place_ids_query(lat, lng) do
    from d in "delivery_areas",
      as: :area,
      join: p in "places",
      on: p.id == d.place_id,
      where: p.status == "verified",
      where:
        fragment(
          "ST_DWithin(?::geography, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?)",
          p.geom,
          ^lng,
          ^lat,
          d.radius_m
        ),
      where:
        not exists(
          from x in "delivery_area_exclusions",
            join: n in "neighborhoods",
            on: n.id == x.neighborhood_id,
            where: x.delivery_area_id == parent_as(:area).id,
            where:
              fragment(
                "ST_Contains(?, ST_SetSRID(ST_MakePoint(?, ?), 4326))",
                n.geom,
                ^lng,
                ^lat
              ),
            select: 1
        ),
      select: type(d.place_id, Ecto.UUID)
  end

  defp create_default(place_id, served_neighborhood_ids) do
    ensure_point(place_id)

    area =
      Repo.insert!(%DeliveryArea{
        place_id: place_id,
        radius_m: @default_radius_m
      })

    excluded =
      place_id
      |> neighborhood_distances()
      |> Enum.filter(&(&1.distance_m != nil and &1.distance_m <= @default_radius_m))
      |> Enum.map(& &1.id)
      |> Enum.reject(&(&1 in served_neighborhood_ids))

    insert_exclusions(area.id, excluded)
    :ok
  end

  # The point defaults to the centroid of the place's neighborhood, and is kept once set.
  defp ensure_point(place_id) do
    Repo.query!(
      """
      UPDATE places SET geom = (
        SELECT ST_Centroid(n.geom)
        FROM neighborhoods n
        JOIN places p ON p.neighborhood_id = n.id
        WHERE p.id = $1
      )
      WHERE id = $1 AND geom IS NULL
      """,
      [Ecto.UUID.dump!(place_id)]
    )

    :ok
  end

  defp upsert_area(changeset) do
    Repo.insert(changeset,
      on_conflict: {:replace, [:radius_m, :updated_at]},
      conflict_target: :place_id,
      returning: true
    )
  end

  defp insert_exclusions(_area_id, []), do: :ok

  defp insert_exclusions(area_id, neighborhood_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      neighborhood_ids
      |> Enum.uniq()
      |> Enum.map(
        &%{
          delivery_area_id: area_id,
          neighborhood_id: &1,
          inserted_at: now,
          updated_at: now
        }
      )

    Repo.insert_all(DeliveryAreaExclusion, rows)
    :ok
  end

  defp round_distance(nil), do: nil
  defp round_distance(meters), do: round(meters)
end
