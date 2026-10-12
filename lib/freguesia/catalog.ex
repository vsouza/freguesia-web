defmodule Freguesia.Catalog do
  @moduledoc """
  Leitura do catálogo: bairros do piloto, segmentos, lugares e a home de um bairro
  (PRD §5 e §8).
  """
  import Ecto.Query, warn: false

  alias Freguesia.Catalog.{Neighborhood, Offer, OpeningHours, Place, PlaceCoverage, Segment, Text}
  alias Freguesia.Repo
  alias Freguesia.Reports.{PlaceStat, Stats}

  @doc "Bairros do piloto, em ordem alfabética."
  def list_pilot_neighborhoods do
    Repo.all(from n in Neighborhood, where: n.pilot == true, order_by: n.name)
  end

  def get_pilot_neighborhood_by_slug(slug) do
    Repo.one(from n in Neighborhood, where: n.slug == ^slug and n.pilot == true)
  end

  @doc "Segmentos com as categorias, para o cadastro."
  def list_segments do
    Repo.all(
      from s in Segment,
        order_by: s.name,
        preload: [categories: ^from(c in Freguesia.Catalog.Category, order_by: c.name)]
    )
  end

  def get_segment_by_key(key), do: Repo.get_by(Segment, key: key)

  @doc """
  Lugares verificados que atendem o bairro, na ordem da home (PRD §8):
  abertos antes de fechados e, depois, pelo nome. Anúncios e promoções não entram aqui.

  Cada lugar sai com `hours_status` preenchido e a oferta aprovada (se houver).
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

  @doc "Lugar pelo slug, com a oferta aprovada e o status de horário. `nil` se não existir."
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

  @doc "Oferta aprovada do lugar, se houver. Recebe o lugar com `offers` preloaded."
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
