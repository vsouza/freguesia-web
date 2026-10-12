defmodule Freguesia.Repo.Migrations.CreateAdminsAndAuditLog do
  use Ecto.Migration

  def change do
    create table(:admins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :password_hash, :string, null: false
      add :role, :string, null: false, default: "moderator"
      add :totp_secret, :binary
      add :totp_confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:admins, [:email])
    create constraint(:admins, :admins_role_valid, check: "role IN ('admin','moderator')")

    create table(:audit_log, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :admin_id, references(:admins, type: :binary_id, on_delete: :restrict)
      add :action, :string, null: false
      add :entity, :string, null: false
      add :entity_id, :string
      add :before, :map
      add :after, :map

      timestamps(type: :utc_datetime)
    end

    create index(:audit_log, [:entity, :entity_id])

    # audit_log is immutable: no UPDATE or DELETE, not even by a code mistake.
    execute(
      """
      CREATE OR REPLACE FUNCTION audit_log_immutable() RETURNS trigger
        LANGUAGE plpgsql
        AS $$ BEGIN RAISE EXCEPTION 'audit_log is immutable'; END; $$
      """,
      "DROP FUNCTION IF EXISTS audit_log_immutable()"
    )

    execute(
      """
      CREATE TRIGGER audit_log_no_update_or_delete
        BEFORE UPDATE OR DELETE ON audit_log
        FOR EACH ROW EXECUTE FUNCTION audit_log_immutable()
      """,
      "DROP TRIGGER IF EXISTS audit_log_no_update_or_delete ON audit_log"
    )
  end
end
