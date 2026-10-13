defmodule Freguesia.Reports.Savings do
  @moduledoc """
  Savings bands reported by the customer (PRD §8).

  Each "Sim" with a band becomes a report with the band midpoint. "Não comparei"
  is not part of the average.
  """

  use Gettext, backend: FreguesiaWeb.Gettext

  # {band, midpoint in %}
  @bands [
    {"none", 0},
    {"le10", 5},
    {"le20", 15},
    {"le30", 25},
    {"gt30", 35}
  ]

  @band_keys Enum.map(@bands, fn {key, _mid} -> key end)

  @doc "Bands that count toward the average, in ascending order, with their labels."
  def bands, do: Enum.map(@bands, fn {key, mid} -> {key, mid, label(key)} end)

  @doc "Validates the chosen band. `not_compared` is valid, but is not part of the average."
  def valid_band?(band), do: band == "not_compared" or band in @band_keys

  @doc "Midpoint of the band, or `nil` for `not_compared`."
  def midpoint(band) do
    case Enum.find(@bands, fn {key, _mid} -> key == band end) do
      {_key, mid} -> mid
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
  def label("none"), do: gettext("Same price")
  def label("le10"), do: gettext("Up to 10%")
  def label("le20"), do: gettext("10 to 20%")
  def label("le30"), do: gettext("20 to 30%")
  def label("gt30"), do: gettext("More than 30%")
  def label(_band), do: nil
end
