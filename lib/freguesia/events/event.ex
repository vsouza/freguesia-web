defmodule Freguesia.Events.Event do
  @moduledoc "Linha da tabela `events`, particionada por mês."
  use Freguesia.Schema

  @primary_key {:id, UUIDv7, autogenerate: true}
  schema "events" do
    field :name, :string
    field :props, :map, default: %{}
    field :device_id, :binary_id
    field :user_id, :binary_id

    timestamps()
  end
end
