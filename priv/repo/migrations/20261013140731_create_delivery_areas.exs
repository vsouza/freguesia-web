defmodule Freguesia.Repo.Migrations.CreateDeliveryAreas do
  use Ecto.Migration

  # PRD §6 and §9: a place delivers within a radius around its point, minus the
  # neighborhoods its owner removed. `place_coverage` is derived from these rows.
  def change do
    create table(:delivery_areas, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all), null: false
      add :radius_m, :integer, null: false, default: 3000

      timestamps(type: :utc_datetime)
    end

    create unique_index(:delivery_areas, [:place_id])

    create constraint(:delivery_areas, :delivery_areas_radius_range,
             check: "radius_m BETWEEN 500 AND 6000"
           )

    create table(:delivery_area_exclusions, primary_key: false) do
      add :delivery_area_id,
          references(:delivery_areas, type: :binary_id, on_delete: :delete_all),
          null: false,
          primary_key: true

      add :neighborhood_id,
          references(:neighborhoods, type: :binary_id, on_delete: :delete_all),
          null: false,
          primary_key: true

      timestamps(type: :utc_datetime)
    end
  end
end
