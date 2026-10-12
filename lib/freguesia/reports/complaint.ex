defmodule Freguesia.Reports.Complaint do
  @moduledoc """
  Denúncia de um lugar (tabela `complaints`). Duas denúncias em 7 dias escondem o
  botão de WhatsApp até revisão do backoffice (PRD §4 e §7).
  """
  use Freguesia.Schema

  schema "complaints" do
    belongs_to :place, Freguesia.Catalog.Place
    field :source, Ecto.Enum, values: [:report, :form]
    field :reason, Ecto.Enum, values: [:wrong_or_scam, :other]
    field :details, :string
    field :status, Ecto.Enum, values: [:open, :reviewing, :closed], default: :open
    field :resolution, :string

    timestamps()
  end
end
