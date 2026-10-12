defmodule Freguesia.Reports.Complaint do
  @moduledoc """
  Complaint about a place (`complaints` table). Two complaints within 7 days hide the
  WhatsApp button until the backoffice reviews it (PRD §4 and §7).
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
