defmodule Freguesia.Reports.SavingsTest do
  use ExUnit.Case, async: true

  alias Freguesia.Reports.Savings

  test "a faixa da média segue os limites do PRD (§8)" do
    assert Savings.band_for_average(0) == "none"
    assert Savings.band_for_average(5) == "le10"
    assert Savings.band_for_average(10) == "le10"
    assert Savings.band_for_average(10.5) == "le20"
    assert Savings.band_for_average(30) == "le30"
    assert Savings.band_for_average(31) == "gt30"
    assert Savings.band_for_average(nil) == nil
  end

  test "faixas válidas e não comparei" do
    assert Savings.valid_band?("le10")
    assert Savings.valid_band?("not_compared")
    refute Savings.valid_band?("gigante")
    refute Savings.valid_band?(nil)
  end
end
