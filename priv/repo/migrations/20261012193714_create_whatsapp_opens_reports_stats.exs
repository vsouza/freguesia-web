defmodule Freguesia.Repo.Migrations.CreateWhatsappOpensReportsStats do
  use Ecto.Migration

  def change do
    create table(:whatsapp_opens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :device_id, :binary_id, null: false

      add :neighborhood_id, references(:neighborhoods, type: :binary_id, on_delete: :restrict)

      add :opened_at, :utc_datetime, null: false
      add :responded_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:whatsapp_opens, [:place_id, :opened_at])
    create index(:whatsapp_opens, [:device_id])

    create table(:reports, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :open_id, references(:whatsapp_opens, type: :binary_id, on_delete: :restrict),
        null: false

      add :place_id, references(:places, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :device_id, :binary_id, null: false
      add :outcome, :string, null: false
      add :savings_band, :string
      add :fail_reason, :string
      add :valid, :boolean, null: false, default: true
      add :weight, :decimal, precision: 3, scale: 2, null: false, default: 1.0
      add :answered_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # One answer per opening.
    create unique_index(:reports, [:open_id])
    create index(:reports, [:place_id, :answered_at])
    create index(:reports, [:device_id, :place_id, :answered_at])

    create constraint(:reports, :reports_outcome_valid, check: "outcome IN ('worked','failed')")

    create constraint(:reports, :reports_savings_band_valid,
             check:
               "savings_band IS NULL OR savings_band IN ('none','le10','le20','le30','gt30','not_compared')"
           )

    create constraint(:reports, :reports_fail_reason_valid,
             check:
               "fail_reason IS NULL OR fail_reason IN ('app_only','no_coverage','no_answer','wrong_or_scam')"
           )

    create table(:place_stats, primary_key: false) do
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :window, :string, primary_key: true
      add :opens, :integer, null: false, default: 0
      add :responses, :integer, null: false, default: 0
      add :worked, :integer, null: false, default: 0
      add :savings_avg, :decimal, precision: 6, scale: 2
      add :savings_hist, :map, null: false, default: %{}
      add :reports_count, :integer, null: false, default: 0
      add :computed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create table(:complaints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all), null: false
      add :source, :string, null: false
      add :reason, :string, null: false
      add :details, :text
      add :status, :string, null: false, default: "open"
      add :resolution, :text

      timestamps(type: :utc_datetime)
    end

    create index(:complaints, [:place_id])
    create index(:complaints, [:status])
  end
end
