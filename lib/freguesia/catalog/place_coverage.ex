defmodule Freguesia.Catalog.PlaceCoverage do
  @moduledoc "Neighborhoods served by a place, besides its own (N:N, PRD §9)."

  use Freguesia.Schema

  @primary_key false
  schema "place_coverage" do
    belongs_to :place, Freguesia.Catalog.Place, primary_key: true
    belongs_to :neighborhood, Freguesia.Catalog.Neighborhood, primary_key: true

    timestamps()
  end
end
