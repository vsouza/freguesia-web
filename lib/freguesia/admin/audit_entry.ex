defmodule Freguesia.Admin.AuditEntry do
  @moduledoc """
  `audit_log` row. Immutable: a Postgres trigger blocks UPDATE and DELETE.
  """
  use Freguesia.Schema

  schema "audit_log" do
    belongs_to :operator, Freguesia.Admin.Operator, foreign_key: :admin_id
    field :action, :string
    field :entity, :string
    field :entity_id, :string
    field :before, :map
    field :after, :map

    timestamps()
  end
end
