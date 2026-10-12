defmodule Freguesia.Catalog.Category do
  @moduledoc "Categoria dentro de um segmento, por exemplo pizza ou japonesa (PRD §9)."

  use Freguesia.Schema

  schema "categories" do
    belongs_to :segment, Freguesia.Catalog.Segment
    field :key, :string
    field :name, :string
    field :color_key, :string

    timestamps()
  end
end
