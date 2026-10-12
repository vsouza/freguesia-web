defmodule Freguesia.Reports.Stats do
  @moduledoc """
  Materializes `place_stats` per 30- and 90-day window (PRD §8 and §9).

  Only valid reports count toward the answer and savings numbers. "Não comparei"
  counts as an answer, but is not part of the average or the histogram.
  """
  import Ecto.Query, warn: false

  alias Freguesia.Repo
  alias Freguesia.Reports.{Open, PlaceStat, Report, Savings}

  @windows [{"30d", 30}, {"90d", 90}]

  @doc "Recomputes both windows for all places with activity."
  def refresh(now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)

    for {window, days} <- @windows do
      since = DateTime.add(now, -days * 86_400)
      rows = window_rows(window, since, now)

      Repo.insert_all(PlaceStat, rows,
        on_conflict: {:replace_all_except, [:place_id, :window, :inserted_at]},
        conflict_target: [:place_id, :window]
      )
    end

    :ok
  end

  defp window_rows(window, since, now) do
    opens = opens_by_place(since)
    reports = reports_by_place(since)

    place_ids = Enum.uniq(Map.keys(opens) ++ Map.keys(reports))

    Enum.map(place_ids, fn place_id ->
      place_reports = Map.get(reports, place_id, [])
      valid = Enum.filter(place_reports, & &1.valid)
      worked = Enum.filter(valid, &(&1.outcome == :worked))
      bands = Enum.filter(worked, &(&1.savings_band not in [nil, "not_compared"]))

      %{
        place_id: place_id,
        window: window,
        opens: Map.get(opens, place_id, 0),
        responses: length(valid),
        worked: length(worked),
        savings_avg: average(bands),
        savings_hist: histogram(bands),
        reports_count: length(place_reports),
        computed_at: now,
        inserted_at: now,
        updated_at: now
      }
    end)
  end

  defp opens_by_place(since) do
    Repo.all(
      from o in Open,
        where: o.opened_at >= ^since,
        group_by: o.place_id,
        select: {o.place_id, count(o.id)}
    )
    |> Map.new()
  end

  defp reports_by_place(since) do
    Repo.all(
      from r in Report,
        where: r.answered_at >= ^since,
        select: %{
          place_id: r.place_id,
          valid: r.valid,
          outcome: r.outcome,
          savings_band: r.savings_band
        }
    )
    |> Enum.group_by(& &1.place_id)
  end

  # Simple average of the band midpoints (PRD §8). `nil` without reports.
  defp average([]), do: nil

  defp average(bands) do
    total = bands |> Enum.map(&Savings.midpoint(&1.savings_band)) |> Enum.sum()
    Decimal.div(Decimal.new(total), Decimal.new(length(bands))) |> Decimal.round(2)
  end

  # Count per band, covering only the five savings bands.
  defp histogram(bands) do
    bands
    |> Enum.frequencies_by(& &1.savings_band)
    |> Map.new(fn {band, count} -> {band, count} end)
  end

  @doc """
  Window of a place with `stats` already loaded (home and card). No row means zeros.
  """
  def window(%{stats: stats, id: place_id}, window) when is_list(stats) do
    Enum.find(stats, &(&1.window == window)) || %PlaceStat{window: window, place_id: place_id}
  end

  @doc ~s(Stats for a place: `%{"30d" => %PlaceStat{}, "90d" => %PlaceStat{}}`, zeros when there is no row.)
  def for_place(place_id) do
    rows =
      Repo.all(from s in PlaceStat, where: s.place_id == ^place_id)
      |> Map.new(&{&1.window, &1})

    Map.new(@windows, fn {window, _days} ->
      {window, Map.get(rows, window, %PlaceStat{window: window, place_id: place_id})}
    end)
  end
end
