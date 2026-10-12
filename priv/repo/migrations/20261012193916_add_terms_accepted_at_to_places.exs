defmodule Freguesia.Repo.Migrations.AddTermsAcceptedAtToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      # Terms acceptance recorded with the date at signup (PRD §13)
      add :terms_accepted_at, :utc_datetime
    end
  end
end
