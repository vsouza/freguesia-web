defmodule Freguesia.Repo.Migrations.CreateCatalog do
  use Ecto.Migration

  def change do
    create table(:segments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :name, :string, null: false
      add :color_key, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:segments, [:key])

    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :segment_id, references(:segments, type: :binary_id, on_delete: :restrict), null: false
      add :key, :string, null: false
      add :name, :string, null: false
      add :color_key, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:segment_id, :key])
  end
end
