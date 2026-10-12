defmodule FreguesiaWeb.Admin.VerificationsLive do
  @moduledoc "Fila de verificações do backoffice (PRD §7)."
  use FreguesiaWeb, :live_view

  alias Freguesia.Verification

  @filters [
    {:pending, "Novos"},
    {:in_review, "Em análise"},
    {:needs_changes, "Aguardando ajuste"},
    {:all, "Todos"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Verificações", filters: @filters)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter = parse_filter(params["filter"])
    requests = Verification.list_requests(filter)

    {:noreply,
     socket
     |> assign(
       filter: filter,
       counts: Verification.count_by_status(),
       empty?: requests == []
     )
     |> stream(:requests, requests, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} operator={@operator}>
      <div class="flex flex-col gap-6">
        <header class="flex flex-wrap items-end justify-between gap-4">
          <h1 class="text-2xl font-extrabold tracking-tight">Verificações</h1>
          <nav aria-label="Filtros" class="flex flex-wrap gap-2">
            <.link
              :for={{key, label} <- @filters}
              patch={~p"/admin/verificacoes?filter=#{key}"}
              aria-current={@filter == key && "page"}
              class={[
                "rounded-full px-4 py-2 text-sm font-bold transition",
                @filter == key && "bg-ink text-white",
                @filter != key && "bg-white text-ink-2 ring-1 ring-line hover:bg-sand"
              ]}
            >
              {label}
              <span class="ml-1 opacity-70">{count_for(@counts, key)}</span>
            </.link>
          </nav>
        </header>

        <div id="requests" phx-update="stream" class="flex flex-col gap-3">
          <div id="requests-empty" class="hidden only:block">
            <.empty_state title="Nada para decidir agora">
              Quando um restaurante confirmar o WhatsApp, o pedido aparece aqui.
            </.empty_state>
          </div>

          <div
            :for={{dom_id, request} <- @streams.requests}
            id={dom_id}
            class="flex flex-wrap items-center justify-between gap-4 rounded-card border border-line bg-white p-5"
          >
            <div class="min-w-0">
              <p class="text-xs font-bold uppercase tracking-wide text-muted">
                {request.place.segment.name}{if request.place.category,
                  do: " · #{request.place.category.name}"}
              </p>
              <h2 class="truncate text-lg font-extrabold">{request.place.name}</h2>
              <p class="text-sm text-ink-2">
                {request.place.neighborhood.name} · {request.place.whatsapp_e164} · recebido {time_ago(
                  request.inserted_at
                )}
              </p>
            </div>

            <div class="flex items-center gap-3">
              <.status_badge status={request.status} />
              <.link
                navigate={~p"/admin/verificacoes/#{request.id}"}
                class="rounded-full bg-ink px-4 py-2 text-sm font-bold text-white hover:bg-ink-2"
              >
                Analisar
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "rounded-full px-3 py-1 text-xs font-bold",
      @status == :pending && "bg-saffron-100 text-saffron-800",
      @status == :in_review && "bg-indigo-100 text-indigo-800",
      @status == :needs_changes && "bg-sand text-ink-2"
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  defp parse_filter(value) when value in ~w(pending in_review needs_changes all) do
    String.to_existing_atom(value)
  end

  defp parse_filter(_), do: :pending

  defp count_for(counts, :all), do: counts |> Map.values() |> Enum.sum()
  defp count_for(counts, key), do: Map.get(counts, key, 0)

  defp status_label(:pending), do: "Novo"
  defp status_label(:in_review), do: "Em análise"
  defp status_label(:needs_changes), do: "Aguardando ajuste"
  defp status_label(:approved), do: "Aprovado"
  defp status_label(:rejected), do: "Recusado"

  defp time_ago(datetime) do
    minutes = DateTime.diff(DateTime.utc_now(), datetime, :second) |> div(60)

    cond do
      minutes < 1 -> "agora"
      minutes < 60 -> "há #{minutes} min"
      minutes < 60 * 24 -> "há #{div(minutes, 60)} h"
      true -> "há #{div(minutes, 60 * 24)} d"
    end
  end
end
