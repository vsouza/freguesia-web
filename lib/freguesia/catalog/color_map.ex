defmodule Freguesia.Catalog.ColorMap do
  @moduledoc """
  Color map per category (PRD §12).

  The classes are written out in full here so Tailwind can generate them.
  Never build class names by concatenation.
  """

  @families %{
    "pessego" => %{top: "bg-pessego-top", tint: "bg-pessego-tint", accent: "text-pessego-accent"},
    "tomate" => %{top: "bg-tomate-top", tint: "bg-tomate-tint", accent: "text-tomate-accent"},
    "laranja" => %{top: "bg-laranja-top", tint: "bg-laranja-tint", accent: "text-laranja-accent"},
    "milho" => %{top: "bg-milho-top", tint: "bg-milho-tint", accent: "text-milho-accent"},
    "cacau" => %{top: "bg-cacau-top", tint: "bg-cacau-tint", accent: "text-cacau-accent"},
    "vinho" => %{top: "bg-vinho-top", tint: "bg-vinho-tint", accent: "text-vinho-accent"},
    "pitaya" => %{top: "bg-pitaya-top", tint: "bg-pitaya-tint", accent: "text-pitaya-accent"},
    "uva" => %{top: "bg-uva-top", tint: "bg-uva-tint", accent: "text-uva-accent"},
    "indigo" => %{top: "bg-indigo-top", tint: "bg-indigo-tint", accent: "text-indigo-accent"},
    "agua" => %{top: "bg-agua-top", tint: "bg-agua-tint", accent: "text-agua-accent"},
    "concreto" => %{
      top: "bg-concreto-top",
      tint: "bg-concreto-tint",
      accent: "text-concreto-accent"
    }
  }

  # An unverified place uses `sand`, with no category color.
  @neutral %{top: "bg-sand", tint: "bg-sand", accent: "text-ink-2"}

  @doc "Map classes for the `color_key` of a segment or category."
  def for_key(key) when is_binary(key), do: Map.get(@families, key, @neutral)
  def for_key(_), do: @neutral

  def neutral, do: @neutral
end
