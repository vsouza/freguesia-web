defmodule Freguesia.Reports.Open do
  @moduledoc """
  WhatsApp opening: each click on "Pedir no WhatsApp" (`whatsapp_opens` table).
  Append-only: a resposta preenche `responded_at`, nunca apaga a linha.
  """
  use Freguesia.Schema

  schema "whatsapp_opens" do
    belongs_to :place, Freguesia.Catalog.Place
    field :device_id, :binary_id
    belongs_to :neighborhood, Freguesia.Catalog.Neighborhood
    field :opened_at, :utc_datetime
    field :responded_at, :utc_datetime

    timestamps()
  end
end
