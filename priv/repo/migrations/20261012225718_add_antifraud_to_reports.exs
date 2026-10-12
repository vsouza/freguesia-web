defmodule Freguesia.Repo.Migrations.AddAntifraudToReports do
  use Ecto.Migration

  def change do
    alter table(:reports) do
      # HMAC hash of the IP /24, with a salt that changes daily. Expires after 30 days (PRD §8, §13).
      add :ip24_hash, :binary
      # Why the report became invalid: device_limit or batch_review.
      add :invalid_reason, :string
    end

    create index(:reports, [:ip24_hash, :answered_at])
  end
end
