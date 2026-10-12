defmodule Freguesia.Catalog.Text do
  @moduledoc """
  Normalização de nomes para busca e slugs (PRD §5, Buscar).

  Mesma regra da busca da home: sem acento, minúsculas, `&` vira `e`.
  """

  @doc """
  Devolve o nome em forma comparável.

      iex> Freguesia.Catalog.Text.normalize("Pizzaria & Padaria Açaí")
      "pizzaria e padaria acai"
  """
  def normalize(name) when is_binary(name) do
    name
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace("&", " e ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  @doc """
  Gera um slug de URL a partir do nome.

      iex> Freguesia.Catalog.Text.slugify("Pizzaria & Padaria Açaí!")
      "pizzaria-e-padaria-acai"
  """
  def slugify(name) when is_binary(name) do
    name
    |> normalize()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
