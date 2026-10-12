defmodule Freguesia.Catalog.Text do
  @moduledoc """
  Name normalization for search and slugs (PRD §5, Search).

  Same rule as the home search: no accents, lowercase, `&` becomes `e`.
  """

  @doc """
  Returns the name in a comparable form.

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
  Generates a URL slug from the name.

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
