defmodule Freguesia.Catalog.Category do
  @moduledoc "Category within a segment, for example pizza or Japanese (PRD §9)."

  use Freguesia.Schema

  schema "categories" do
    belongs_to :segment, Freguesia.Catalog.Segment
    field :key, :string
    field :name, :string
    field :color_key, :string

    timestamps()
  end
end
