defmodule Freguesia.Reports.Savings do
  @moduledoc """
  Savings bands reported by the customer (PRD §8).

  Each "Sim" with a band becomes a report with the band midpoint. "Não comparei"
  is not part of the average.
  """

  # {band, midpoint in %, label shown to the customer}
  @bands [
    {"none", 0, "Mesmo preço"},
    {"le10", 5, "Até 10%"},
    {"le20", 15, "10 a 20%"},
    {"le30", 25, "20 a 30%"},
    {"gt30", 35, "Mais de 30%"}
  ]

  @band_keys Enum.map(@bands, fn {key, _mid, _label} -> key end)

  @doc "Bands that count toward the average, in ascending order."
  def bands, do: @bands

  @doc "Validates the chosen band. `not_compared` is valid, but is not part of the average."
  def valid_band?(band), do: band == "not_compared" or band in @band_keys

  @doc "Midpoint of the band, or `nil` for `not_compared`."
  def midpoint(band) do
    case Enum.find(@bands, fn {key, _mid, _label} -> key == band end) do
      {_key, mid, _label} -> mid
      nil -> nil
    end
  end

  @doc """
  Band that contains an average in percentage points (to highlight it in the histogram).
  Average 0 is "Mesmo preço"; (0, 10] is "Até 10%"; and so on.
  """
  def band_for_average(nil), do: nil
  def band_for_average(avg) when avg <= 0, do: "none"
  def band_for_average(avg) when avg <= 10, do: "le10"
  def band_for_average(avg) when avg <= 20, do: "le20"
  def band_for_average(avg) when avg <= 30, do: "le30"
  def band_for_average(_avg), do: "gt30"

  @doc "Band label, for the screen."
  def label(band) do
    case Enum.find(@bands, fn {key, _mid, _label} -> key == band end) do
      {_key, _mid, label} -> label
      nil -> nil
    end
  end
end
