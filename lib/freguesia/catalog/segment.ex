defmodule Freguesia.Catalog.Segment do
  @moduledoc "Catalog segment: restaurants, pharmacies, markets, hardware, pet (PRD §9)."

  use Freguesia.Schema

  schema "segments" do
    field :key, :string
    field :name, :string
    field :color_key, :string

    has_many :categories, Freguesia.Catalog.Category

    timestamps()
  end
end
