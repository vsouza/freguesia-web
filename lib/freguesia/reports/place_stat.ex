defmodule Freguesia.Reports.PlaceStat do
  @moduledoc """
  Números de um lugar por janela (30 ou 90 dias), materializados pelo job a cada
  15 minutos (PRD §9). A home lê esta tabela e nunca agrega na requisição.
  """
  use Freguesia.Schema

  @primary_key false
  schema "place_stats" do
    belongs_to :place, Freguesia.Catalog.Place, primary_key: true
    field :window, :string, primary_key: true
    field :opens, :integer, default: 0
    field :responses, :integer, default: 0
    field :worked, :integer, default: 0
    field :savings_avg, :decimal
    field :savings_hist, :map, default: %{}
    field :reports_count, :integer, default: 0
    field :computed_at, :utc_datetime

    timestamps()
  end
end
