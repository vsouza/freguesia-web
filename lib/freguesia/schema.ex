defmodule Freguesia.Schema do
  @moduledoc """
  Base for the domain schemas: UUIDv7 primary keys (PRD §9) and UTC timestamps, without
  sub-second fractions.

      use Freguesia.Schema
  """

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset

      @primary_key {:id, UUIDv7, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime]
    end
  end
end
