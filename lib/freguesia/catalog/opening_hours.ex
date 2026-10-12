defmodule Freguesia.Catalog.OpeningHours do
  @moduledoc """
  Open/closed status computed per request (PRD §8).

  `opening_hours` is a map keyed by weekday, with intervals in minutes since
  midnight, in the `America/Sao_Paulo` timezone:

      %{"mon" => [[660, 1320]], "sat" => [[660, 780], [1080, 1380]]}

  Missing days or `[]` = closed. "Pausado hoje" overrides the schedule.
  """

  @timezone "America/Sao_Paulo"
  @days ~w(mon tue wed thu fri sat sun)

  @type status ::
          {:open, closes_at :: String.t()}
          | {:closed, opens_at :: String.t() | nil}
          | {:paused}

  @doc """
  Returns the place's status at the instant `now`.

      iex> hours = %{"mon" => [[660, 1320]]}
      iex> Freguesia.Catalog.OpeningHours.status(hours, nil, ~U[2026-10-12 15:00:00Z])
      {:open, "22h"}
  """
  @spec status(map(), DateTime.t() | nil, DateTime.t()) :: status()
  def status(hours, paused_until, now \\ DateTime.utc_now()) do
    local = DateTime.shift_zone!(now, @timezone)
    minute = local.hour * 60 + local.minute

    cond do
      paused?(paused_until, now) ->
        {:paused}

      interval = Enum.find(intervals_on(hours, local), &contains?(&1, minute)) ->
        [_from, to] = interval
        {:open, label_hour(to)}

      true ->
        {:closed, next_opening(hours, local, minute)}
    end
  end

  defp paused?(nil, _now), do: false
  defp paused?(paused_until, now), do: DateTime.compare(paused_until, now) == :gt

  defp contains?([from, to], minute), do: minute >= from and minute < to

  defp intervals_on(hours, %DateTime{} = local) do
    key = Enum.at(@days, Date.day_of_week(local) - 1)
    Map.get(hours, key, [])
  end

  # Next opening: the first interval of today that has not started yet, or the
  # first interval of the next 7 days.
  defp next_opening(hours, local, minute) do
    today = DateTime.to_date(local)

    Enum.find_value(0..7, fn offset ->
      day = Date.add(today, offset)
      day_key = Enum.at(@days, Date.day_of_week(day) - 1)

      hours
      |> Map.get(day_key, [])
      |> Enum.find(fn [from, _to] -> offset > 0 or from > minute end)
      |> case do
        [from, _to] -> label_hour(from)
        nil -> nil
      end
    end)
  end

  defp label_hour(minutes) do
    hour = div(minutes, 60)
    minute = rem(minutes, 60)

    if minute == 0,
      do: "#{hour}h",
      else: "#{hour}h#{String.pad_leading(Integer.to_string(minute), 2, "0")}"
  end
end
