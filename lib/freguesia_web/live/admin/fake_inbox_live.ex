defmodule FreguesiaWeb.Admin.FakeInboxLive do
  @moduledoc """
  Caixa do WhatsApp fake (`/admin/mensagens-fake`). Mostra o que o adaptador
  `Freguesia.Messaging.Fake` "enviou", incluindo o código de verificação.
  Só existe com o adaptador fake ligado; em produção com a API real ela fica vazia.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Messaging.Fake

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Mensagens (fake)", messages: Enum.reverse(Fake.all()))}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    Fake.clear()
    {:noreply, assign(socket, messages: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} operator={@operator}>
      <div class="mx-auto flex max-w-2xl flex-col gap-4">
        <div class="flex items-center justify-between">
          <h1 class="text-xl font-extrabold">Mensagens enviadas (fake)</h1>
          <button id="clear-inbox" phx-click="clear" class="text-sm font-bold underline">
            Limpar
          </button>
        </div>

        <p :if={@messages == []} class="text-sm text-muted">Nenhuma mensagem ainda.</p>

        <div
          :for={message <- @messages}
          id={"message-#{message.id}"}
          class="rounded-card border border-line bg-white p-4 text-sm"
        >
          <p class="font-bold">
            {message.to} <span class="font-normal text-muted">· {message.template}</span>
          </p>
          <pre class="mt-2 whitespace-pre-wrap text-xs text-ink-2">{inspect(message.params, pretty: true)}</pre>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
