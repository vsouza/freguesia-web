defmodule Freguesia.Repo.Migrations.CreateUsersAndFavorites do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :name, :string
      add :avatar_url, :string
      add :provider, :string, null: false

      add :default_neighborhood_id,
          references(:neighborhoods, type: :binary_id, on_delete: :nilify_all)

      add :confirmed_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:user_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token_hash])

    create table(:favorites, primary_key: false) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      timestamps(type: :utc_datetime)
    end
  end
end
