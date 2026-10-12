defmodule Freguesia.Messaging do
  @moduledoc """
  Envio de mensagens transacionais por WhatsApp (PRD §11).

  Só mensagens utilitárias e de autenticação. Nada de marketing.
  O adaptador vem de `config :freguesia, :messaging`; em dev e teste é
  `Freguesia.Messaging.Fake`.

  Código de verificação é enviado na hora, sem fila: o argumento de um job
  Oban fica gravado em `oban_jobs`, e o código não pode ficar em texto puro.
  Mensagens sem segredo (aprovação, pedido de ajuste) passam pela fila
  `Freguesia.Workers.SendWhatsApp`, com retry.
  """

  alias Freguesia.Workers.SendWhatsApp

  @callback deliver(to :: String.t(), template :: String.t(), params :: map()) ::
              :ok | {:error, term()}

  @doc "Envia agora. Usado para o código de verificação."
  def deliver(to, template, params) do
    adapter().deliver(to, template, params)
  end

  @doc "Enfileira um envio com retry. Não use para segredos."
  def enqueue(to, template, params) do
    %{"to" => to, "template" => template, "params" => params}
    |> SendWhatsApp.new()
    |> Oban.insert()
  end

  defp adapter, do: Application.fetch_env!(:freguesia, :messaging)
end
