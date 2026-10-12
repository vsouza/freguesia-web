defmodule Freguesia.Schema do
  @moduledoc """
  Base dos schemas do domínio: PK UUIDv7 (PRD §9) e timestamps em UTC, sem
  frações de segundo.

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
