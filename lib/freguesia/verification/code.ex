defmodule Freguesia.Verification.Code do
  @moduledoc """
  Código de 6 dígitos enviado ao WhatsApp do restaurante (PRD §6).

  Só o HMAC do código fica no banco. Validade de 10 minutos, 3 tentativas.
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
