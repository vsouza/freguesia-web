defmodule Freguesia.Admin.AuditEntry do
  @moduledoc """
  Linha do `audit_log`. Imutável: um trigger no Postgres bloqueia UPDATE e DELETE.
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
