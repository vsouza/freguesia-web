defmodule Freguesia.Repo.Migrations.CreatePlaces do
  use Ecto.Migration

  @statuses "'pending','needs_changes','rejected','verified','paused','hidden','removed'"

  def change do
    # Busca sem acento: unaccent não é IMMUTABLE, então o índice usa este wrapper.
    execute(
      """
      CREATE OR REPLACE FUNCTION immutable_unaccent(text) RETURNS text
        LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
        AS $$ SELECT unaccent('unaccent', $1) $$
      """,
      "DROP FUNCTION IF EXISTS immutable_unaccent(text)"
    )

    create table(:places, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :segment_id, references(:segments, type: :binary_id, on_delete: :restrict), null: false
      add :category_id, references(:categories, type: :binary_id, on_delete: :restrict)

      add :neighborhood_id, references(:neighborhoods, type: :binary_id, on_delete: :restrict),
        null: false

      add :geom, :"geometry(Point, 4326)"
      add :whatsapp_e164, :string, null: false
      add :wa_profile_name, :string
      add :status, :string, null: false, default: "pending"
      add :delivery_mode, :string, null: false, default: "own"
      add :opening_hours, :map, null: false, default: %{}
      add :photo_key, :string
      add :paused_until, :utc_datetime
      add :verified_at, :utc_datetime
      add :removed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:places, :places_status_valid, check: "status IN (#{@statuses})")

    create constraint(:places, :places_delivery_mode_valid,
             check: "delivery_mode IN ('own','partner')"
           )

    create unique_index(:places, [:slug])
    create unique_index(:places, [:whatsapp_e164], where: "removed_at IS NULL")
    create index(:places, [:neighborhood_id, :status])
    create index(:places, [:geom], using: :gist)

    execute(
      "CREATE INDEX places_name_trgm_idx ON places USING gin (immutable_unaccent(lower(name)) gin_trgm_ops)",
      "DROP INDEX IF EXISTS places_name_trgm_idx"
    )

    create table(:place_coverage, primary_key: false) do
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :neighborhood_id,
          references(:neighborhoods, type: :binary_id, on_delete: :delete_all),
          primary_key: true

      timestamps(type: :utc_datetime)
    end

    create table(:offers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all), null: false
      add :text, :string, size: 80, null: false
      add :tag, :string, size: 14
      add :status, :string, null: false, default: "pending"
      add :updated_by_place_at, :utc_datetime
      add :approved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:offers, :offers_status_valid,
             check: "status IN ('pending','approved','rejected')"
           )

    create index(:offers, [:place_id])
    # Uma oferta aprovada (ativa) por lugar; o histórico fica nas demais linhas.
    create unique_index(:offers, [:place_id],
             where: "status = 'approved'",
             name: :offers_one_approved_per_place
           )
  end
end
