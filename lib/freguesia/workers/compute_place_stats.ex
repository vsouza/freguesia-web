defmodule Freguesia.Workers.ComputePlaceStats do
  @moduledoc "Recomputes `place_stats` every 15 minutes (PRD §9)."
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Freguesia.Reports.Stats

  @impl Oban.Worker
  def perform(_job) do
    Stats.refresh()
  end
end
