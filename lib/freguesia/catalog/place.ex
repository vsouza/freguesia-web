defmodule Freguesia.Catalog.Place do
  @moduledoc """
  Um lugar do catálogo: restaurante, farmácia, mercado, construção ou pet.

  O `status` nunca entra no `cast`: só o domínio de verificação muda o status,
  sempre pela transição certa e com registro em `audit_log`.
  """
  use Freguesia.Schema

  @type t :: %__MODULE__{}

  @statuses [:pending, :needs_changes, :rejected, :verified, :paused, :hidden, :removed]
  @delivery_modes [:own, :partner]

  schema "places" do
    field :name, :string
    field :slug, :string
    belongs_to :segment, Freguesia.Catalog.Segment
    belongs_to :category, Freguesia.Catalog.Category
    belongs_to :neighborhood, Freguesia.Catalog.Neighborhood
    field :whatsapp_e164, :string
    field :wa_profile_name, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :delivery_mode, Ecto.Enum, values: @delivery_modes, default: :own
    field :opening_hours, :map, default: %{}
    field :photo_key, :string
    field :paused_until, :utc_datetime
    field :verified_at, :utc_datetime
    field :removed_at, :utc_datetime
    field :terms_accepted_at, :utc_datetime

    has_many :coverage, Freguesia.Catalog.PlaceCoverage
    has_many :offers, Freguesia.Catalog.Offer
    has_many :stats, Freguesia.Reports.PlaceStat

    # Calculado por requisição (PRD §8), nunca persistido.
    field :hours_status, :any, virtual: true

    timestamps()
  end

  @doc "Changeset de cadastro. Campos gerados pelo sistema ficam de fora."
  def registration_changeset(place, attrs) do
    place
    |> cast(attrs, [
      :name,
      :segment_id,
      :category_id,
      :neighborhood_id,
      :whatsapp_e164,
      :delivery_mode
    ])
    |> validate_required([:name, :segment_id, :neighborhood_id, :whatsapp_e164])
    |> validate_length(:name, min: 3, max: 60)
    |> validate_format(:whatsapp_e164, ~r/^\+55[1-9]\d{9,10}$/,
      message: "use um WhatsApp brasileiro com DDD"
    )
    |> assoc_constraint(:segment)
    |> assoc_constraint(:neighborhood)
    |> unique_constraint(:whatsapp_e164,
      name: :places_whatsapp_e164_index,
      message: "este número já está cadastrado"
    )
  end

  @doc false
  def status_changeset(place, status, extra \\ %{}) do
    place
    |> change(status: status)
    |> change(extra)
  end

  def statuses, do: @statuses
end
