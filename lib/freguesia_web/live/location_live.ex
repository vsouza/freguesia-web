defmodule FreguesiaWeb.LocationLive do
  @moduledoc """
  Location step (PRD §5): browser geolocation or a manual neighborhood choice.

  The browser sends the point to this process once. It is resolved to a pilot
  neighborhood with PostGIS. The point and the neighborhood then go to the
  session through a POST (`LocationController.geo/2`), never through the URL.
  Coordinates are not stored in the database (PRD §5 and §13).
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Location"),
       neighborhoods: Catalog.list_pilot_neighborhoods(),
       geo: to_form(%{"neighborhood" => "", "lat" => "", "lng" => ""}, as: :geo),
       submit_geo: false
     )}
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
        geo =
          to_form(
            %{"neighborhood" => neighborhood.slug, "lat" => lat, "lng" => lng},
            as: :geo
          )

        {:noreply, assign(socket, geo: geo, submit_geo: true)}
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
            href={~p"/location/#{neighborhood.slug}"}
            class="flex min-h-11 items-center rounded-full border border-line px-4 font-semibold text-ink hover:bg-sand"
          >
            {neighborhood.name}
          </.link>
        </li>
      </ul>

      <.form
        for={@geo}
        id="geo-form"
        action={~p"/location/geo"}
        phx-trigger-action={@submit_geo}
        class="hidden"
      >
        <input
          :for={field <- [:neighborhood, :lat, :lng]}
          type="hidden"
          name={@geo[field].name}
          value={@geo[field].value}
        />
      </.form>

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
