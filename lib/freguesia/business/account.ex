defmodule Freguesia.Business.Account do
  @moduledoc """
  A business account (PRD §6). Created or refreshed from a verified Firebase ID token,
  keyed by the Firebase uid. Manages the places it is a member of.
  """

  use Freguesia.Schema

  @providers [:google, :apple, :password]

  schema "business_accounts" do
    field :firebase_uid, :string
    field :email, :string
    field :name, :string
    field :avatar_url, :string
    field :provider, Ecto.Enum, values: @providers, default: :password
    field :last_login_at, :utc_datetime
    field :disabled_at, :utc_datetime

    timestamps()
  end
end
