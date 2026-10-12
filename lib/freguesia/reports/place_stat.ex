defmodule Freguesia.Reports.PlaceStat do
  @moduledoc """
  A place's numbers per window (30 or 90 days), materialized by the job every
  15 minutes (PRD §9). The home reads this table and never aggregates during the request.
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
