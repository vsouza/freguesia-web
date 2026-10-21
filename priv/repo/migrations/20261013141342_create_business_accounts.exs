defmodule Freguesia.Repo.Migrations.CreateBusinessAccounts do
  use Ecto.Migration

  # PRD §6: business accounts come from Firebase Authentication. The verified WhatsApp
  # number still identifies the place; the account identifies the person who manages it.
  def change do
    create table(:business_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :firebase_uid, :string, null: false
      add :email, :citext
      add :name, :string
      add :avatar_url, :string
      add :provider, :string, null: false, default: "password"
      add :last_login_at, :utc_datetime
      add :disabled_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:business_accounts, [:firebase_uid])

    create constraint(:business_accounts, :business_accounts_provider_valid,
             check: "provider IN ('google','apple','password')"
           )

    create table(:place_members, primary_key: false) do
      add :business_account_id,
          references(:business_accounts, type: :binary_id, on_delete: :delete_all),
          null: false,
          primary_key: true

      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :role, :string, null: false, default: "owner"

      timestamps(type: :utc_datetime)
    end

    create index(:place_members, [:place_id])

    create constraint(:place_members, :place_members_role_valid,
             check: "role IN ('owner','manager')"
           )
  end
end
