defmodule Freguesia.Repo.Migrations.AddTermsAcceptedAtToPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      # Aceite dos termos registrado com data no cadastro (PRD §13)
      add :terms_accepted_at, :utc_datetime
    end
  end
end
