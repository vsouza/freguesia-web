defmodule Freguesia.Catalog.Segment do
  @moduledoc "Segmento do catálogo: restaurantes, farmácias, mercados, construção, pet (PRD §9)."

  use Freguesia.Schema

  schema "segments" do
    field :key, :string
    field :name, :string
    field :color_key, :string

    has_many :categories, Freguesia.Catalog.Category

    timestamps()
  end
end
