defmodule Freguesia.Business.Membership do
  @moduledoc "Links a business account to a place it manages (PRD §6). The registering account is the owner."

  use Freguesia.Schema

  @primary_key false
  schema "place_members" do
    belongs_to :business_account, Freguesia.Business.Account, primary_key: true
    belongs_to :place, Freguesia.Catalog.Place, primary_key: true
    field :role, Ecto.Enum, values: [:owner, :manager], default: :owner

    timestamps()
  end
end
