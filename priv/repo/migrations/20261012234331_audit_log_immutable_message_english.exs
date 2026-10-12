defmodule Freguesia.Repo.Migrations.AuditLogImmutableMessageEnglish do
  use Ecto.Migration

  # Only the error text changes; the trigger itself stays the same.
  @old "audit_log é imutável"
  @new "audit_log is immutable"

  def up do
    execute """
    CREATE OR REPLACE FUNCTION audit_log_immutable() RETURNS trigger
      LANGUAGE plpgsql
      AS $$ BEGIN RAISE EXCEPTION '#{@new}'; END; $$
    """
  end

  def down do
    execute """
    CREATE OR REPLACE FUNCTION audit_log_immutable() RETURNS trigger
      LANGUAGE plpgsql
      AS $$ BEGIN RAISE EXCEPTION '#{@old}'; END; $$
    """
  end
end
