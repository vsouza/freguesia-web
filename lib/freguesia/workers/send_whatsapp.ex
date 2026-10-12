defmodule Freguesia.Workers.SendWhatsApp do
  @moduledoc """
  Envio em fila de mensagens sem segredo (aprovação, pedido de ajuste).

  Retry exponencial: 30 s, 60 s, 120 s, 240 s, até 5 tentativas (PRD §11).
  """
  use Oban.Worker, queue: :messaging, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"to" => to, "template" => template, "params" => params}}) do
    Freguesia.Messaging.deliver(to, template, params)
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    min(30 * Integer.pow(2, attempt - 1), 1800)
  end
end
