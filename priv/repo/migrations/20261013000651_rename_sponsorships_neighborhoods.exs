defmodule Freguesia.Repo.Migrations.RenameSponsorshipsNeighborhoods do
  use Ecto.Migration

  # Column name follows the PRD data model (neighborhood_ids).
  def change do
    rename table(:sponsorships), :neighborhoods, to: :neighborhood_ids
  end
end
