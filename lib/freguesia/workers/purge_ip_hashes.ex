defmodule Freguesia.Workers.PurgeIpHashes do
  @moduledoc "Deletes the /24 hash of reports older than 30 days (PRD §13). Daily."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    Freguesia.Reports.purge_ip_hashes()
    :ok
  end
end
