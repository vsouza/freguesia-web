defmodule Freguesia.Catalog.Promotion do
  @moduledoc """
  A promotion published by a place (PRD §6 and §9). Moderated before it shows:
  only `approved` promotions from verified places reach the Promotions tab.
  """

  use Freguesia.Schema

  @statuses [:pending, :approved, :rejected]

  schema "promotions" do
    belongs_to :place, Freguesia.Catalog.Place
    field :title, :string
    field :body, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :status, Ecto.Enum, values: @statuses, default: :pending
    # Phase 3: paid promotions. Stays false during the pilot.
    field :paid, :boolean, default: false
    field :amount_cents, :integer

    timestamps()
  end
end
