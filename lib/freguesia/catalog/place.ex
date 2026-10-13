defmodule Freguesia.Catalog.Place do
  @moduledoc """
  A catalog place: restaurant, pharmacy, market, hardware store or pet shop.

  `status` never goes into the `cast`: only the verification domain changes the status,
  always through the right transition and with a record in `audit_log`.
  """
  use Freguesia.Schema

  use Gettext, backend: FreguesiaWeb.Gettext

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

    # Computed per request (PRD §8), never persisted.
    field :hours_status, :any, virtual: true

    timestamps()
  end

  @doc "Signup changeset. System-generated fields are left out."
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
      message: dgettext("errors", "use a Brazilian WhatsApp number with area code")
    )
    |> assoc_constraint(:segment)
    |> assoc_constraint(:neighborhood)
    |> unique_constraint(:whatsapp_e164,
      name: :places_whatsapp_e164_index,
      message: dgettext("errors", "this number is already registered")
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
