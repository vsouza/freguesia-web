defmodule Freguesia.Messaging.Fake do
  @moduledoc """
  Dev and test adapter. Keeps the messages in an ETS table so that the
  dev inbox (`/dev/mensagens`) and the tests can read what
  "went out" to WhatsApp.
  """
  @behaviour Freguesia.Messaging

  use GenServer

  @table __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl GenServer
  def init(nil) do
    :ets.new(@table, [:named_table, :public, :ordered_set, read_concurrency: true])
    {:ok, nil}
  end

  @impl Freguesia.Messaging
  def deliver(to, template, params) do
    id = System.unique_integer([:monotonic, :positive])

    message = %{
      id: id,
      to: to,
      template: template,
      params: params,
      sent_at: DateTime.utc_now()
    }

    :ets.insert(@table, {id, message})
    :ok
  end

  @doc "All messages, from oldest to newest."
  def all do
    @table |> :ets.tab2list() |> Enum.map(fn {_id, message} -> message end)
  end

  @doc "Messages sent to a number (E.164)."
  def sent_to(to), do: Enum.filter(all(), &(&1.to == to))

  @doc "Clears the history. For dev use only."
  def clear, do: :ets.delete_all_objects(@table)
end
