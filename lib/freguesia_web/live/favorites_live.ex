defmodule FreguesiaWeb.FavoritesLive do
  @moduledoc """
  Favorites tab (PRD §5). Without an account, favorites live in this device's
  `localStorage` as place slugs. The page sends the slugs to the server, which
  returns only the places that are still verified.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Catalog

  @max_favorites 50

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Favorites"),
       current_neighborhood: session["neighborhood"] || "savassi",
       places_count: 0
     )
     |> stream(:places, [])}
  end

  @impl true
  def handle_event("load", %{"slugs" => slugs}, socket) when is_list(slugs) do
    places =
      slugs
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()
      |> Enum.take(@max_favorites)
      |> Enum.map(&Catalog.get_place_by_slug/1)
      |> Enum.reject(&(is_nil(&1) or &1.status != :verified))

    {:noreply,
     socket
     |> assign(places_count: length(places))
     |> stream(:places, places, reset: true)}
  end

  def handle_event("load", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active_tab={:favorites} current_neighborhood={@current_neighborhood}>
      <FreguesiaWeb.Components.two_line_title first={gettext("Your")} second={gettext("favorites")} />

      <div id="favorites-sync" phx-hook=".Favorites" class="hidden"></div>

      <div :if={@places_count == 0} id="favorites-empty" class="mt-6">
        <FreguesiaWeb.Components.empty_state title={gettext("No favorites yet")}>
          {gettext("Tap the heart on a place to keep it here, on this device.")}
        </FreguesiaWeb.Components.empty_state>
      </div>

      <div
        id="favorite-places"
        phx-update="stream"
        class="mt-6 grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3"
      >
        <div :for={{dom_id, place} <- @streams.places} id={dom_id}>
          <FreguesiaWeb.Components.place_card place={place} />
        </div>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".Favorites">
        // Key shared with the favorite button on the place page.
        const KEY = "freguesia:favorites"

        function readFavorites() {
          try {
            const slugs = JSON.parse(window.localStorage.getItem(KEY) || "[]")
            return Array.isArray(slugs) ? slugs : []
          } catch (_) {
            return []
          }
        }

        export default {
          mounted() {
            this.pushEvent("load", {slugs: readFavorites()})
          }
        }
      </script>
    </Layouts.app>
    """
  end
end
