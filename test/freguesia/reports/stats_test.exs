defmodule Freguesia.Reports.StatsTest do
  use Freguesia.DataCase, async: true

  alias Freguesia.{Fixtures, Reports}
  alias Freguesia.Reports.Stats

  @now ~U[2026-10-12 15:00:00Z]

  defp answer!(place, device, attrs, at \\ @now) do
    {:ok, open} = Reports.open_whatsapp(place.id, device, at)
    {:ok, report} = Reports.answer(open.id, attrs, %{device_id: device, ip24_hash: nil}, at)
    report
  end

  defp device(i), do: "6666666#{i}-6666-7666-8666-66666666666#{i}"

  test "simple average of the band midpoints and a histogram per band" do
    place = Fixtures.verified_place()

    answer!(place, device(1), %{outcome: :worked, band: "le10"})
    answer!(place, device(2), %{outcome: :worked, band: "gt30"})

    Stats.refresh(@now)
    stat = Stats.for_place(place.id)["90d"]

    assert Decimal.equal?(stat.savings_avg, Decimal.new("20.00"))
    assert stat.savings_hist == %{"le10" => 1, "gt30" => 1}
    assert stat.worked == 2
    assert stat.responses == 2
  end

  test "'not compared' counts as an answer but not in the average or the histogram" do
    place = Fixtures.verified_place()

    answer!(place, device(1), %{outcome: :worked, band: "not_compared"})
    answer!(place, device(2), %{outcome: :failed, reason: :no_answer})

    Stats.refresh(@now)
    stat = Stats.for_place(place.id)["30d"]

    assert stat.responses == 2
    assert stat.worked == 1
    assert stat.savings_avg == nil
    assert stat.savings_hist == %{}
  end

  test "invalid reports do not count in the response numbers" do
    place = Fixtures.verified_place()

    # The same device answers 4 times: the 4th is invalid (limit of 3 per 30 days)
    for _ <- 1..4 do
      answer!(place, device(1), %{outcome: :worked, band: "le10"})
    end

    Stats.refresh(@now)
    stat = Stats.for_place(place.id)["30d"]

    assert stat.reports_count == 4
    assert stat.responses == 3
    assert stat.worked == 3
  end

  test "the 30-day window excludes old reports, the 90-day one does not" do
    place = Fixtures.verified_place()
    old = DateTime.add(@now, -45 * 86_400)
    answer!(place, device(1), %{outcome: :worked, band: "le10"}, old)

    Stats.refresh(@now)
    stats = Stats.for_place(place.id)

    assert stats["30d"].responses == 0
    assert stats["90d"].responses == 1
  end

  test "a place without activity has zeros and no row in the database" do
    place = Fixtures.verified_place()
    stats = Stats.for_place(place.id)

    assert stats["30d"].worked == 0
    assert stats["30d"].savings_hist == %{}
    assert stats["90d"].savings_avg == nil
  end

  test "refresh is idempotent" do
    place = Fixtures.verified_place()
    answer!(place, device(1), %{outcome: :worked, band: "le20"})

    Stats.refresh(@now)
    Stats.refresh(@now)

    assert Stats.for_place(place.id)["30d"].responses == 1
  end
end
