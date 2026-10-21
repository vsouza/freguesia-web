defmodule Freguesia.Catalog.DeliveryArea do
  @moduledoc """
  Where a place delivers: a radius around the place's point (PRD §6 and §9).
  One area per place. Neighborhoods the owner removed live in
  `Freguesia.Catalog.DeliveryAreaExclusion`.
  """

  use Freguesia.Schema

  schema "delivery_areas" do
    belongs_to :place, Freguesia.Catalog.Place
    field :radius_m, :integer, default: 3000

    has_many :exclusions, Freguesia.Catalog.DeliveryAreaExclusion, foreign_key: :delivery_area_id

    timestamps()
  end

  @doc "Radius in meters: 500 to 6000, in steps of 500 (PRD §6)."
  def changeset(area, attrs) do
    area
    |> Ecto.Changeset.cast(attrs, [:radius_m])
    |> Ecto.Changeset.validate_number(:radius_m,
      greater_than_or_equal_to: 500,
      less_than_or_equal_to: 6000
    )
    |> Ecto.Changeset.validate_change(:radius_m, fn :radius_m, radius ->
      if rem(radius, 500) == 0, do: [], else: [radius_m: "must be a multiple of 500"]
    end)
    |> Ecto.Changeset.assoc_constraint(:place)
  end
end
