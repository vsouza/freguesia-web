defmodule Freguesia.Workers.PurgeIpHashes do
  @moduledoc "Apaga o hash do /24 de relatos com mais de 30 dias (PRD §13). Diário."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(_job) do
    Freguesia.Reports.purge_ip_hashes()
    :ok
  end
end
