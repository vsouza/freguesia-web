defmodule Freguesia.Repo.Migrations.CreateAdsAndPromotions do
  use Ecto.Migration

  def change do
    create table(:promotions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :body, :text
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :status, :string, null: false, default: "pending"
      # Phases 2 and 3: paid only becomes true once billing exists.
      add :paid, :boolean, null: false, default: false
      add :amount_cents, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:promotions, [:place_id])

    create table(:sponsorships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :neighborhoods, {:array, :binary_id}, null: false, default: []
      add :status, :string, null: false, default: "pending"
      add :amount_cents, :integer

      timestamps(type: :utc_datetime)
    end

    create constraint(:sponsorships, :sponsorships_kind_valid,
             check: "kind IN ('own_detail','also_nearby')"
           )

    create index(:sponsorships, [:place_id])

    create table(:ad_slots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :network, :string, null: false, default: "adsense"
      add :enabled, :boolean, null: false, default: false
      add :blocked_categories, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ad_slots, [:key])
  end
end
