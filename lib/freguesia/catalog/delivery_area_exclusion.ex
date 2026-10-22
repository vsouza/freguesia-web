defmodule Freguesia.Catalog.DeliveryAreaExclusion do
  @moduledoc "A neighborhood removed from a delivery area, even when it lies inside the radius."

  use Freguesia.Schema

  @primary_key false
  schema "delivery_area_exclusions" do
    belongs_to :delivery_area, Freguesia.Catalog.DeliveryArea, primary_key: true
    belongs_to :neighborhood, Freguesia.Catalog.Neighborhood, primary_key: true

    timestamps()
  end
end
