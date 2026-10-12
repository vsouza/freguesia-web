defmodule Freguesia.Catalog.Neighborhood do
  @moduledoc "Neighborhood. `pilot` marks the pilot neighborhoods (PRD §9)."

  use Freguesia.Schema

  # `geom` (PostGIS polygon) is not part of the schema: it is read and written by SQL,
  # and resolving the neighborhood with ST_Contains is left for phase 1 (PRD §11).
  schema "neighborhoods" do
    belongs_to :city, Freguesia.Catalog.City
    field :name, :string
    field :slug, :string
    field :pilot, :boolean, default: false

    timestamps()
  end
end
