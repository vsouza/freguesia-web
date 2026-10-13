defmodule Freguesia.Catalog.ColorMap do
  @moduledoc """
  Color map per category (PRD §12).

  The classes are written out in full here so Tailwind can generate them.
  Never build class names by concatenation.
  """

  @families %{
    "peach" => %{
      top: "bg-cat-peach-top",
      tint: "bg-cat-peach-tint",
      accent: "text-cat-peach-accent",
      gradient: "from-cat-peach-top"
    },
    "tomato" => %{
      top: "bg-cat-tomato-top",
      tint: "bg-cat-tomato-tint",
      accent: "text-cat-tomato-accent",
      gradient: "from-cat-tomato-top"
    },
    "orange" => %{
      top: "bg-cat-orange-top",
      tint: "bg-cat-orange-tint",
      accent: "text-cat-orange-accent",
      gradient: "from-cat-orange-top"
    },
    "corn" => %{
      top: "bg-cat-corn-top",
      tint: "bg-cat-corn-tint",
      accent: "text-cat-corn-accent",
      gradient: "from-cat-corn-top"
    },
    "cocoa" => %{
      top: "bg-cat-cocoa-top",
      tint: "bg-cat-cocoa-tint",
      accent: "text-cat-cocoa-accent",
      gradient: "from-cat-cocoa-top"
    },
    "wine" => %{
      top: "bg-cat-wine-top",
      tint: "bg-cat-wine-tint",
      accent: "text-cat-wine-accent",
      gradient: "from-cat-wine-top"
    },
    "pitaya" => %{
      top: "bg-cat-pitaya-top",
      tint: "bg-cat-pitaya-tint",
      accent: "text-cat-pitaya-accent",
      gradient: "from-cat-pitaya-top"
    },
    "grape" => %{
      top: "bg-cat-grape-top",
      tint: "bg-cat-grape-tint",
      accent: "text-cat-grape-accent",
      gradient: "from-cat-grape-top"
    },
    "indigo" => %{
      top: "bg-cat-indigo-top",
      tint: "bg-cat-indigo-tint",
      accent: "text-cat-indigo-accent",
      gradient: "from-cat-indigo-top"
    },
    "water" => %{
      top: "bg-cat-water-top",
      tint: "bg-cat-water-tint",
      accent: "text-cat-water-accent",
      gradient: "from-cat-water-top"
    },
    "concrete" => %{
      top: "bg-cat-concrete-top",
      tint: "bg-cat-concrete-tint",
      accent: "text-cat-concrete-accent",
      gradient: "from-cat-concrete-top"
    }
  }

  # An unverified place uses `sand`, with no category color.
  @neutral %{top: "bg-sand", tint: "bg-sand", accent: "text-ink-2", gradient: "from-sand"}

  @doc "Map classes for the `color_key` of a segment or category."
  def for_key(key) when is_binary(key), do: Map.get(@families, key, @neutral)
  def for_key(_), do: @neutral

  def neutral, do: @neutral
end
