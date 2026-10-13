defmodule FreguesiaWeb.Admin.PlacesLive do
  @moduledoc "Places list in the backoffice: search by name and filter by status (PRD §7)."
  use FreguesiaWeb, :live_view

  alias Freguesia.Backoffice

  @statuses ~w(all verified pending needs_changes paused hidden removed rejected)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Places"), statuses: @statuses)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{query: blank_to_nil(params["q"]), status: params["status"] || "all"}
    places = Backoffice.list_places(filters)

    {:noreply,
     socket
     |> assign(filters: filters, empty?: places == [])
     |> stream(:places, places, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} operator={@operator}>
      <div class="flex flex-col gap-6">
        <h1 class="text-2xl font-extrabold tracking-tight">{gettext("Places")}</h1>

        <form id="places-filter" method="get" action={~p"/admin/places"} class="flex flex-wrap gap-3">
          <input
            type="search"
            name="q"
            value={@filters.query}
            placeholder={gettext("Search by name")}
            class="h-11 min-w-64 rounded-full border border-line bg-white px-4"
          />
          <select name="status" class="h-11 rounded-full border border-line bg-white px-4">
            <option :for={status <- @statuses} value={status} selected={@filters.status == status}>
              {status_label(status)}
            </option>
          </select>
          <button type="submit" class="h-11 rounded-full bg-ink px-5 font-bold text-white">
            {gettext("Filter")}
          </button>
        </form>

        <div id="places" phx-update="stream" class="flex flex-col gap-2">
          <div
            :for={{dom_id, place} <- @streams.places}
            id={dom_id}
            class="flex flex-wrap items-center justify-between gap-3 rounded-card border border-line bg-white p-4"
          >
            <div class="min-w-0">
              <p class="font-bold">{place.name}</p>
              <p class="text-sm text-ink-2">{place.neighborhood.name} · {place.whatsapp_e164}</p>
            </div>
            <div class="flex items-center gap-3">
              <span class="rounded-full bg-sand px-3 py-1 text-xs font-bold">
                {status_label(to_string(place.status))}
              </span>
              <.link
                navigate={~p"/admin/places/#{place.id}"}
                class="rounded-full bg-ink px-4 py-2 text-sm font-bold text-white"
              >
                {gettext("Open")}
              </.link>
            </div>
          </div>
        </div>

        <div :if={@empty?} class="rounded-card bg-white p-6 text-sm text-ink-2">
          {gettext("No places match these filters.")}
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp status_label("all"), do: gettext("All statuses")
  defp status_label("verified"), do: gettext("Verified")
  defp status_label("pending"), do: gettext("Pending")
  defp status_label("needs_changes"), do: gettext("Needs changes")
  defp status_label("paused"), do: gettext("Paused")
  defp status_label("hidden"), do: gettext("Hidden")
  defp status_label("removed"), do: gettext("Removed")
  defp status_label("rejected"), do: gettext("Rejected")
  defp status_label(other), do: other

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
