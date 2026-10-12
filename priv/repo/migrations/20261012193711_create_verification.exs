defmodule Freguesia.Repo.Migrations.CreateVerification do
  use Ecto.Migration

  def change do
    create table(:verification_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all), null: false
      # Código nunca em texto puro: só o hash.
      add :code_hash, :binary, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, null: false, default: 0
      add :confirmed_at, :utc_datetime
      add :channel, :string, null: false, default: "whatsapp"

      timestamps(type: :utc_datetime)
    end

    create index(:verification_codes, [:place_id])

    create table(:verification_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :checks, :map, null: false, default: %{}
      add :notes, :text

      add :decided_by_id, references(:admins, type: :binary_id, on_delete: :restrict)
      add :decided_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:verification_requests, :verification_requests_status_valid,
             check: "status IN ('pending','in_review','needs_changes','approved','rejected')"
           )

    create index(:verification_requests, [:place_id])
    create index(:verification_requests, [:status])
  end
end
