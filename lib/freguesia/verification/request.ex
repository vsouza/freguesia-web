defmodule Freguesia.Verification.Request do
  @moduledoc """
  Pedido de verificação na fila do backoffice (tabela `verification_requests`).

  Nasce quando o código do WhatsApp é confirmado. Cada decisão do operador
  muda o `status` do pedido e o do lugar, na mesma transação.
  """
  use Freguesia.Schema

  @statuses [:pending, :in_review, :needs_changes, :approved, :rejected]

  schema "verification_requests" do
    belongs_to :place, Freguesia.Catalog.Place
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :checks, :map, default: %{}
    field :notes, :string
    belongs_to :decided_by, Freguesia.Admin.Operator, foreign_key: :decided_by_id
    field :decided_at, :utc_datetime

    timestamps()
  end

  def statuses, do: @statuses
  def open_statuses, do: [:pending, :in_review, :needs_changes]
end
