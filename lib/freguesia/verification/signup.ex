defmodule Freguesia.Verification.Signup do
  @moduledoc """
  Signup form in 3 steps, step 1 (PRD §6).

  Format validations live here. Those that depend on the catalog (pilot neighborhood,
  food type required for restaurants) live in `Freguesia.Verification`.
  """
  use Ecto.Schema

  import Ecto.Changeset

  use Gettext, backend: FreguesiaWeb.Gettext

  alias Freguesia.Verification.Phone

  @primary_key false
  embedded_schema do
    field :name, :string
    field :segment_id, :binary_id
    field :category_id, :binary_id
    field :neighborhood_id, :binary_id
    field :whatsapp, :string
    field :delivery_mode, Ecto.Enum, values: [:own, :partner], default: :own
    field :coverage_ids, {:array, :binary_id}, default: []
    field :offer_text, :string
    field :accept_terms, :boolean, default: false
  end

  @required [:name, :segment_id, :neighborhood_id, :whatsapp]
  @castable [
    :name,
    :segment_id,
    :category_id,
    :neighborhood_id,
    :whatsapp,
    :delivery_mode,
    :coverage_ids,
    :offer_text,
    :accept_terms
  ]

  def changeset(form, attrs) do
    form
    |> cast(attrs, @castable)
    |> update_change(:name, &trim_or_nil/1)
    |> update_change(:offer_text, &trim_or_nil/1)
    |> validate_required(@required, message: dgettext("errors", "is required"))
    |> validate_length(:name,
      min: 3,
      max: 60,
      message: dgettext("errors", "use between 3 and 60 characters")
    )
    |> validate_length(:offer_text, max: 80, message: dgettext("errors", "up to 80 characters"))
    |> validate_whatsapp()
    |> validate_acceptance(:accept_terms,
      message: dgettext("errors", "accept the terms to continue")
    )
  end

  defp validate_whatsapp(changeset) do
    validate_change(changeset, :whatsapp, fn :whatsapp, value ->
      case Phone.normalize(value) do
        {:ok, _} -> []
        :error -> [whatsapp: dgettext("errors", "use a Brazilian WhatsApp number with area code")]
      end
    end)
  end

  defp trim_or_nil(nil), do: nil

  defp trim_or_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
