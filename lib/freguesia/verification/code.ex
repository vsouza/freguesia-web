defmodule Freguesia.Verification.Code do
  @moduledoc """
  6-digit code sent to the restaurant's WhatsApp (PRD §6).

  Only the code's HMAC is stored in the database. Valid for 10 minutes, 3 attempts.
  """
  use Freguesia.Schema

  schema "verification_codes" do
    belongs_to :place, Freguesia.Catalog.Place
    field :code_hash, :binary, redact: true
    field :expires_at, :utc_datetime
    field :attempts, :integer, default: 0
    field :confirmed_at, :utc_datetime
    field :channel, :string, default: "whatsapp"

    timestamps()
  end
end
