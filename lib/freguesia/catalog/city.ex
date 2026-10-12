defmodule Freguesia.Catalog.City do
  @moduledoc "Catalog city. In the pilot, only Belo Horizonte (PRD §9)."

  use Freguesia.Schema

  schema "cities" do
    field :name, :string
    field :slug, :string
    field :state, :string
    field :active, :boolean, default: true

    timestamps()
  end
end
