defmodule FreguesiaWeb.NeighborhoodLive do
  @moduledoc """
  Home of a pilot neighborhood: verified places that serve the neighborhood (PRD §5).
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Catalog

  @default_slug "savassi"

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Catalog.get_pilot_neighborhood_by_slug(slug) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/bairro/#{@default_slug}")}

      neighborhood ->
        places = Catalog.list_home_places(neighborhood)

        {:ok,
         socket
         |> assign(page_title: neighborhood.name, neighborhood: neighborhood)
         |> stream(:places, places)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <header class="flex items-start justify-between gap-4 pb-6">
        <div>
          <p class="text-xs font-bold uppercase tracking-wide text-muted">Bairro</p>
          <h1 class="text-3xl font-extrabold tracking-tight text-ink">{@neighborhood.name}</h1>
          <p class="mt-1 text-sm text-muted">
            Lugares verificados pelo próprio restaurante.
          </p>
        </div>
        <.link
          navigate={~p"/cadastrar"}
          class="flex-none rounded-full border border-line px-4 py-2 text-sm font-bold text-ink hover:bg-sand"
        >
          Tenho um restaurante
        </.link>
      </header>

      <div id="places" phx-update="stream" class="flex flex-col gap-4">
        <div id="places-empty" class="hidden only:block">
          <.empty_state title="Chegam em breve">
            Ainda não há lugares verificados neste bairro. Se você atende por WhatsApp, faça o cadastro e apareça aqui.
          </.empty_state>
        </div>

        <div :for={{dom_id, place} <- @streams.places} id={dom_id}>
          <.place_card place={place} />
        </div>
      </div>
    </Layouts.app>
    """
  end
end
