defmodule Freguesia.Repo.Migrations.AddPromotionToSponsorships do
  use Ecto.Migration

  # The own ad (PRD §6) shows a promotion of the place: the sponsorship points to it.
  def change do
    alter table(:sponsorships) do
      add :promotion_id, references(:promotions, type: :binary_id, on_delete: :delete_all)
    end

    create index(:sponsorships, [:promotion_id])
  end
end
