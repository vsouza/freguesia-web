defmodule Freguesia.Messaging do
  @moduledoc """
  Sends transactional WhatsApp messages (PRD §11).

  Utility and authentication messages only. No marketing.
  The adapter comes from `config :freguesia, :messaging`; in dev and test it is
  `Freguesia.Messaging.Fake`.

  The verification code is sent right away, with no queue: a job argument
  in Oban is stored in `oban_jobs`, and the code must not sit there in plain text.
  Messages without secrets (approval, adjustment request) go through the queue
  `Freguesia.Workers.SendWhatsApp`, with retries.
  """

  alias Freguesia.Workers.SendWhatsApp

  @callback deliver(to :: String.t(), template :: String.t(), params :: map()) ::
              :ok | {:error, term()}

  @doc "Sends now. Used for the verification code."
  def deliver(to, template, params) do
    adapter().deliver(to, template, params)
  end

  @doc "Enqueues a send with retries. Do not use for secrets."
  def enqueue(to, template, params) do
    %{"to" => to, "template" => template, "params" => params}
    |> SendWhatsApp.new()
    |> Oban.insert()
  end

  defp adapter, do: Application.fetch_env!(:freguesia, :messaging)
end
