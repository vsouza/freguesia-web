defmodule Freguesia.Reports.Savings do
  @moduledoc """
  Faixas de economia relatadas pelo freguês (PRD §8).

  Cada "Sim" com faixa vira um relato com o ponto médio da faixa. "Não comparei"
  não entra na média.
  """

  # {faixa, ponto médio em %, rótulo para o freguês}
  @bands [
    {"none", 0, "Mesmo preço"},
    {"le10", 5, "Até 10%"},
    {"le20", 15, "10 a 20%"},
    {"le30", 25, "20 a 30%"},
    {"gt30", 35, "Mais de 30%"}
  ]

  @band_keys Enum.map(@bands, fn {key, _mid, _label} -> key end)

  @doc "Faixas que contam para a média, em ordem crescente."
  def bands, do: @bands

  @doc "Valida a faixa escolhida. `not_compared` é válido, mas não entra na média."
  def valid_band?(band), do: band == "not_compared" or band in @band_keys

  @doc "Ponto médio da faixa, ou `nil` para `not_compared`."
  def midpoint(band) do
    case Enum.find(@bands, fn {key, _mid, _label} -> key == band end) do
      {_key, mid, _label} -> mid
      nil -> nil
    end
  end

  @doc """
  Faixa que contém uma média em pontos percentuais (para destacar no histograma).
  Média 0 é "Mesmo preço"; (0, 10] é "Até 10%"; e assim por diante.
  """
  def band_for_average(nil), do: nil
  def band_for_average(avg) when avg <= 0, do: "none"
  def band_for_average(avg) when avg <= 10, do: "le10"
  def band_for_average(avg) when avg <= 20, do: "le20"
  def band_for_average(avg) when avg <= 30, do: "le30"
  def band_for_average(_avg), do: "gt30"

  @doc "Rótulo da faixa, para a tela."
  def label(band) do
    case Enum.find(@bands, fn {key, _mid, _label} -> key == band end) do
      {_key, _mid, label} -> label
      nil -> nil
    end
  end
end
