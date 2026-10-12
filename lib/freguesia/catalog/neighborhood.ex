defmodule Freguesia.Catalog.Neighborhood do
  @moduledoc "Bairro. `pilot` marca os bairros do piloto (PRD §9)."

  use Freguesia.Schema

  # `geom` (polígono PostGIS) não entra no schema: é lido e escrito por SQL,
  # e a resolução do bairro por ST_Contains fica para a fase 1 (PRD §11).
  schema "neighborhoods" do
    belongs_to :city, Freguesia.Catalog.City
    field :name, :string
    field :slug, :string
    field :pilot, :boolean, default: false

    timestamps()
  end
end
