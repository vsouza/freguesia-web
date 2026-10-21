defmodule Freguesia.Catalog.Sponsorship do
  @moduledoc """
  A paid placement (PRD §6 and §9). `own_detail` is the place's own ad on its details page,
  showing one of its promotions. Moderated like everything else: it only shows once approved.
  Free during the pilot; `amount_cents` stays nil until billing exists (phase 3).
  """

  use Freguesia.Schema

  @kinds [:own_detail, :also_nearby]
  @statuses [:pending, :approved, :rejected]

  schema "sponsorships" do
    belongs_to :place, Freguesia.Catalog.Place
    belongs_to :promotion, Freguesia.Catalog.Promotion
    field :kind, Ecto.Enum, values: @kinds
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :neighborhood_ids, {:array, :binary_id}, default: []
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :amount_cents, :integer

    timestamps()
  end
end
