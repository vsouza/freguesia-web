defmodule Freguesia.Repo.Migrations.AddAntifraudToReports do
  use Ecto.Migration

  def change do
    alter table(:reports) do
      # Hash HMAC do /24 do IP, com salt que muda por dia. Expira em 30 dias (PRD §8, §13).
      add :ip24_hash, :binary
      # Por que o relato ficou inválido: device_limit ou batch_review.
      add :invalid_reason, :string
    end

    create index(:reports, [:ip24_hash, :answered_at])
  end
end
