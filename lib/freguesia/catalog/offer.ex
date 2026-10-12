defmodule Freguesia.Catalog.Offer do
  @moduledoc """
  Deal provided by the restaurant (PRD §4, rule 4).

  It only shows in the catalog when `status` is `approved`. Every edit by the
  restaurant creates a new `pending` row, and the approved one stays live
  until moderation decides.
  """
  use Freguesia.Schema

  @statuses [:pending, :approved, :rejected, :replaced]

  schema "offers" do
    belongs_to :place, Freguesia.Catalog.Place
    field :text, :string
    field :tag, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :updated_by_place_at, :utc_datetime
    field :approved_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(offer, attrs) do
    offer
    |> cast(attrs, [:text, :tag])
    |> validate_required([:text])
    |> validate_length(:text, max: 80)
    |> validate_length(:tag, max: 14)
  end
end
