defmodule Freguesia.Catalog.Offer do
  @moduledoc """
  Vantagem informada pelo restaurante (PRD §4, regra 4).

  Só aparece no catálogo quando `status` é `approved`. Toda edição do
  restaurante cria uma nova linha `pending`, e a aprovada continua no ar
  até a moderação decidir.
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
