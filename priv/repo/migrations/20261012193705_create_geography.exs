defmodule Freguesia.Repo.Migrations.CreateGeography do
  use Ecto.Migration

  def change do
    create table(:cities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :state, :string, null: false
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:cities, [:slug])

    create table(:neighborhoods, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :city_id, references(:cities, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :geom, :"geometry(Polygon, 4326)"
      add :pilot, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:neighborhoods, [:city_id, :slug])
    create index(:neighborhoods, [:geom], using: :gist)
  end
end
