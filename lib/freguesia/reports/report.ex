defmodule Freguesia.Reports.Report do
  @moduledoc """
  Customer's answer to the question "Conseguiu pedir direto?" (`reports` table).

  One per opening. An invalid report stays in the table with `valid = false` and the reason
  in `invalid_reason`; it is never deleted.
  """
  use Freguesia.Schema

  @outcomes ~w(worked failed)a
  @fail_reasons ~w(app_only no_coverage no_answer wrong_or_scam)a

  schema "reports" do
    belongs_to :open, Freguesia.Reports.Open
    belongs_to :place, Freguesia.Catalog.Place
    field :device_id, :binary_id
    field :outcome, Ecto.Enum, values: @outcomes
    field :savings_band, :string
    field :fail_reason, Ecto.Enum, values: @fail_reasons
    field :valid, :boolean, default: true
    field :invalid_reason, :string
    field :weight, :decimal, default: Decimal.new("1.0")
    field :answered_at, :utc_datetime
    field :ip24_hash, :binary, redact: true

    timestamps()
  end

  def outcomes, do: @outcomes
  def fail_reasons, do: @fail_reasons
end
