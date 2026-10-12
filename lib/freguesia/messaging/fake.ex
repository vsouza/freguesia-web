defmodule Freguesia.Messaging.Fake do
  @moduledoc """
  Adaptador de dev e teste. Guarda as mensagens numa tabela ETS para que a
  caixa de entrada de dev (`/dev/mensagens`) e os testes possam ler o que
  "saiu" para o WhatsApp.
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

  @doc "Todas as mensagens, da mais antiga para a mais nova."
  def all do
    @table |> :ets.tab2list() |> Enum.map(fn {_id, message} -> message end)
  end

  @doc "Mensagens enviadas para um número (E.164)."
  def sent_to(to), do: Enum.filter(all(), &(&1.to == to))

  @doc "Apaga o histórico. Só para uso em dev."
  def clear, do: :ets.delete_all_objects(@table)
end
