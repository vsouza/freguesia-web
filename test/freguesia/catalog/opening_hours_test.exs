defmodule Freguesia.Catalog.OpeningHoursTest do
  use ExUnit.Case, async: true

  alias Freguesia.Catalog.OpeningHours

  # 2026-10-12 is a Monday. Brasília is UTC-3, so 12:00 local = 15:00Z.
  @hours %{
    "mon" => [[660, 1320]],
    "sat" => [[660, 780], [1080, 1380]],
    "sun" => [[720, 1200]]
  }

  # Builds the local time and converts it to UTC (+3h).
  defp at_local(hour, minute, date \\ ~D[2026-10-12]) do
    {:ok, local} = NaiveDateTime.new(date.year, date.month, date.day, hour, minute, 0)
    local |> NaiveDateTime.add(3 * 3600) |> DateTime.from_naive!("Etc/UTC")
  end

  test "open within the interval and reports until when" do
    assert OpeningHours.status(@hours, nil, at_local(12, 0)) == {:open, "22h"}
  end

  test "closed before opening and reports when it opens" do
    assert OpeningHours.status(@hours, nil, at_local(9, 0)) == {:closed, "11h"}
  end

  test "closed after closing time: the next opening is tomorrow" do
    # Monday 23:00: Tuesday has the same schedule as 11h
    assert OpeningHours.status(@hours, nil, at_local(23, 0)) == {:closed, "11h"}
  end

  test "Saturday morning: the lunch break closes in the middle" do
    saturday = ~D[2026-10-17]
    assert OpeningHours.status(@hours, nil, at_local(13, 0, saturday)) == {:closed, "18h"}
  end

  test "a day without hours stays closed and has no next opening this week" do
    assert OpeningHours.status(%{}, nil, at_local(12, 0)) == {:closed, nil}
  end

  test "paused today overrides the schedule" do
    paused_until = DateTime.add(at_local(12, 0), 3600)
    assert OpeningHours.status(@hours, paused_until, at_local(12, 0)) == {:paused}
  end

  test "an expired pause no longer applies" do
    paused_until = DateTime.add(at_local(12, 0), -60)
    assert OpeningHours.status(@hours, paused_until, at_local(12, 0)) == {:open, "22h"}
  end

  test "partial hours appear in the label" do
    hours = %{"mon" => [[660, 1350]]}
    assert OpeningHours.status(hours, nil, at_local(12, 0)) == {:open, "22h30"}
  end
end
