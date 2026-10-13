defmodule FreguesiaWeb.LocationLive do
  @moduledoc """
  Location step (PRD §5): browser geolocation or a manual neighborhood choice.

  The browser sends the point to this process once. It is resolved to a pilot
  neighborhood with PostGIS and discarded. Only the neighborhood slug is kept,
  in the session (PRD §13).
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: gettext("Location"), neighborhoods: Catalog.list_pilot_neighborhoods())}
  end

  @impl true
  def handle_event("located", %{"lat" => lat, "lng" => lng}, socket) do
    case Catalog.pilot_neighborhood_at(lat, lng) do
      nil ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("You are outside the pilot area. Choose a neighborhood below.")
         )}

      neighborhood ->
        {:noreply, redirect(socket, to: ~p"/location/#{neighborhood.slug}?via=geo")}
    end
  end

  def handle_event("denied", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       gettext("We could not get your location. Choose a neighborhood below.")
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <FreguesiaWeb.Components.two_line_title
        first={gettext("Where do you")}
        second={gettext("order from?")}
      />

      <p class="mt-4 text-sm text-ink-2">
        {gettext(
          "We use your location once, to pick your neighborhood. The coordinates are not stored."
        )}
      </p>

      <button
        id="use-location"
        phx-hook=".Geolocation"
        class="mt-6 inline-flex min-h-12 items-center justify-center rounded-full bg-ink px-6 text-base font-bold text-white hover:bg-ink-2"
      >
        {gettext("Use my location")}
      </button>

      <h2 class="mt-10 text-sm font-bold uppercase tracking-wide text-muted">
        {gettext("Or choose a neighborhood")}
      </h2>
      <ul class="mt-3 grid grid-cols-2 gap-2">
        <li :for={neighborhood <- @neighborhoods}>
          <.link
            href={~p"/location/#{neighborhood.slug}?via=manual"}
            class="flex min-h-11 items-center rounded-full border border-line px-4 font-semibold text-ink hover:bg-sand"
          >
            {neighborhood.name}
          </.link>
        </li>
      </ul>

      <.link
        navigate={~p"/areas/savassi"}
        class="mt-10 text-center text-sm font-bold text-muted underline"
      >
        {gettext("Not now")}
      </.link>
    </Layouts.app>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Geolocation">
      export default {
        mounted() {
          this.el.addEventListener("click", () => {
            if (!navigator.geolocation) return this.pushEvent("denied", {})
            navigator.geolocation.getCurrentPosition(
              pos => this.pushEvent("located", {lat: pos.coords.latitude, lng: pos.coords.longitude}),
              () => this.pushEvent("denied", {}),
              {enableHighAccuracy: false, timeout: 10000, maximumAge: 600000}
            )
          })
        }
      }
    </script>
    """
  end
end
