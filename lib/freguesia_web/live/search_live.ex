defmodule FreguesiaWeb.SearchLive do
  @moduledoc """
  Search (`/search`, PRD §5): verified places whose name matches, across the pilot.
  Accent-insensitive, same normalization as the home search.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.{Catalog, Events}

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Search"), device_id: session["device_id"])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = blank_to_nil(params["q"])
    places = if query, do: Catalog.search_places(query), else: []

    if query do
      Events.track("search_performed", %{screen: "search"}, socket.assigns.device_id)
    end

    {:noreply,
     socket
     |> assign(query: query, places_count: length(places))
     |> stream(:places, places, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_neighborhood={@current_neighborhood}
      active_tab={:search}
      wide={true}
    >
      <header class="pb-4">
        <h1 class="text-3xl font-extrabold tracking-tight text-ink">{gettext("Search")}</h1>
      </header>

      <form id="search-form" method="get" action={~p"/search"} class="flex flex-col gap-3">
        <label for="search-input" class="sr-only">{gettext("Search by name")}</label>
        <input
          id="search-input"
          type="search"
          name="q"
          value={@query}
          placeholder={gettext("Search by name")}
          class="block h-12 w-full rounded-full border border-line bg-white px-5 text-base text-ink placeholder:text-muted focus:border-ink focus:outline-none focus:ring-2 focus:ring-ink/10"
        />
      </form>

      <p :if={@query == nil} id="search-prompt" class="mt-6 text-sm text-muted">
        {gettext("Type part of a place name.")}
      </p>

      <div
        id="search-results"
        phx-update="stream"
        class="mt-6 flex flex-col gap-4 md:grid md:grid-cols-3"
      >
        <div :for={{dom_id, place} <- @streams.places} id={dom_id}>
          <FreguesiaWeb.Components.place_card place={place} />
        </div>
      </div>

      <div :if={@query != nil and @places_count == 0} id="search-nothing-found">
        <FreguesiaWeb.Components.empty_state title={gettext("Nothing found")}>
          {gettext("No verified place matches this name.")}
        </FreguesiaWeb.Components.empty_state>
        <.link
          patch={~p"/search"}
          class="mt-3 inline-flex text-sm font-bold text-ink underline underline-offset-4"
        >
          {gettext("Clear filters")}
        </.link>
      </div>
    </Layouts.app>
    """
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
