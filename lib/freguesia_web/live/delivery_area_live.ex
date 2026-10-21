defmodule FreguesiaWeb.DeliveryAreaLive do
  @moduledoc """
  Delivery area of a place (PRD §6): a radius from the place's point, and the
  neighborhoods inside it that the owner keeps or removes. Saving recomputes the
  derived coverage. The map comes later; the list alone covers the same rule.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.{Business, DeliveryAreas}

  @impl true
  def mount(%{"id" => place_id}, _session, socket) do
    case Business.get_place_for(socket.assigns.current_business_account, place_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("That place is not in your account."))
         |> push_navigate(to: ~p"/business/account")}

      place ->
        area = DeliveryAreas.get_for_place(place.id)
        radius_m = if area, do: area.radius_m, else: DeliveryAreas.default_radius_m()
        neighborhoods = DeliveryAreas.neighborhood_distances(place.id)

        {:ok,
         socket
         |> assign(
           page_title: gettext("Delivery area"),
           place: place,
           neighborhoods: neighborhoods,
           has_area?: area != nil,
           radius_m: radius_m,
           point: DeliveryAreas.point_of(place.id),
           included: included_ids(neighborhoods, radius_m, area)
         )}
    end
  end

  @impl true
  def handle_event("change", params, socket) do
    radius_m = radius_from(params["area"]["radius_km"]) || socket.assigns.radius_m
    included = MapSet.new(params["area"]["included"] || [])

    {:noreply, assign(socket, radius_m: radius_m, included: included)}
  end

  # The owner stands at the place and taps "Use my location". The distances change,
  # so the list is rebuilt from the new point and the saved exclusions.
  def handle_event("set_point", %{"lat" => lat, "lng" => lng}, socket) do
    case DeliveryAreas.set_point(socket.assigns.place.id, lat, lng) do
      {:ok, point} ->
        place = socket.assigns.place
        area = DeliveryAreas.get_for_place(place.id)
        neighborhoods = DeliveryAreas.neighborhood_distances(place.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Location saved. Distances are measured from here."))
         |> assign(
           point: point,
           neighborhoods: neighborhoods,
           included: included_ids(neighborhoods, socket.assigns.radius_m, area)
         )}

      {:error, :outside_pilot} ->
        {:noreply,
         put_flash(socket, :error, gettext("This location is outside the pilot neighborhoods."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("We could not read that location."))}
    end
  end

  def handle_event("point_failed", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       gettext("We could not read your location. Allow location access and try again.")
     )}
  end

  def handle_event("save", params, socket) do
    radius_m = radius_from(params["area"]["radius_km"]) || socket.assigns.radius_m
    included = MapSet.new(params["area"]["included"] || [])

    # Neighborhoods inside the radius that the owner did not keep become exclusions.
    excluded =
      socket.assigns.neighborhoods
      |> inside(radius_m)
      |> Enum.map(& &1.id)
      |> Enum.reject(&MapSet.member?(included, &1))

    case DeliveryAreas.save(socket.assigns.place.id, radius_m, excluded) do
      {:ok, area} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Delivery area saved."))
         |> assign(
           has_area?: true,
           radius_m: area.radius_m,
           included: included_ids(socket.assigns.neighborhoods, area.radius_m, area)
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Choose a radius between 0.5 and 6 km."))}
    end
  end

  # Kept neighborhoods start checked. Removed ones start unchecked. Inside-radius rule first.
  defp included_ids(neighborhoods, radius_m, area) do
    excluded = if area, do: Enum.map(area.exclusions, & &1.neighborhood_id), else: []

    neighborhoods
    |> inside(radius_m)
    |> Enum.reject(&(&1.id in excluded))
    |> MapSet.new(& &1.id)
  end

  defp inside(neighborhoods, radius_m) do
    Enum.filter(neighborhoods, &(&1.distance_m != nil and &1.distance_m <= radius_m))
  end

  # The slider sends kilometers with one decimal (step 0.5); the database stores meters.
  defp radius_from(nil), do: nil

  defp radius_from(km) when is_binary(km) do
    case Float.parse(km) do
      {value, _} -> round(value * 1000)
      :error -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_neighborhood={@current_neighborhood}>
      <FreguesiaWeb.Components.two_line_title
        first={gettext("Where you")}
        second={gettext("deliver.")}
      />

      <p class="mt-2 text-sm text-muted">{@place.name} · {@place.neighborhood.name}</p>

      <section class="mt-6 flex flex-col gap-3 rounded-card bg-white p-5 shadow-card">
        <p class="text-sm font-bold text-ink">{gettext("Location of the place")}</p>
        <p class="text-sm text-ink-2">
          {gettext(
            "Stand where the place is and tap the button. Distances are measured from that point."
          )}
        </p>
        <button
          type="button"
          id="set-point"
          phx-hook=".PlacePoint"
          class="min-h-11 w-fit rounded-full border border-line px-5 font-bold text-ink hover:bg-sand"
        >
          {gettext("Use my location")}
        </button>
        <p id="point-status" class="text-xs text-muted">
          <%= if @point do %>
            {gettext("Current point: %{lat}, %{lng}",
              lat: format_coord(elem(@point, 0)),
              lng: format_coord(elem(@point, 1))
            )}
          <% else %>
            {gettext("No point yet, so distances cannot be measured.")}
          <% end %>
        </p>
      </section>

      <form
        id="delivery-area-form"
        phx-change="change"
        phx-submit="save"
        class="mt-6 flex flex-col gap-6"
      >
        <div class="flex flex-col gap-2 rounded-card bg-sand p-5">
          <label
            for="radius-km"
            class="flex items-baseline justify-between text-sm font-bold text-ink"
          >
            {gettext("Radius from the place")}
            <output id="radius-output" class="text-lg font-extrabold">
              {format_km(@radius_m)} km
            </output>
          </label>
          <input
            id="radius-km"
            type="range"
            name="area[radius_km]"
            min="0.5"
            max="6"
            step="0.5"
            value={format_km(@radius_m)}
            class="w-full accent-ink"
          />
          <p class="text-xs text-muted">
            {gettext(
              "Customers inside the radius see your place. Remove a neighborhood below if you don't deliver there."
            )}
          </p>
        </div>

        <fieldset class="flex flex-col gap-2">
          <legend class="mb-2 text-sm font-bold text-ink">{gettext("Neighborhoods")}</legend>
          <ul id="neighborhood-list" class="flex flex-col gap-2">
            <li :for={neighborhood <- @neighborhoods} id={"neighborhood-#{neighborhood.slug}"}>
              <label class={[
                "flex min-h-12 items-center justify-between gap-3 rounded-tile border px-4",
                (neighborhood.distance_m != nil and neighborhood.distance_m <= @radius_m) &&
                  "border-line bg-white",
                !(neighborhood.distance_m != nil and neighborhood.distance_m <= @radius_m) &&
                  "border-dashed border-line bg-sand text-muted"
              ]}>
                <span class="font-semibold">{neighborhood.name}</span>
                <span class="flex items-center gap-3 text-xs">
                  <span :if={neighborhood.distance_m != nil and neighborhood.distance_m > @radius_m}>
                    {gettext("Outside the radius")}
                  </span>
                  <input
                    :if={neighborhood.distance_m != nil and neighborhood.distance_m <= @radius_m}
                    type="checkbox"
                    name="area[included][]"
                    value={neighborhood.id}
                    checked={MapSet.member?(@included, neighborhood.id)}
                    class="size-5 accent-ink"
                  />
                </span>
              </label>
            </li>
          </ul>
        </fieldset>

        <p id="coverage-summary" class="text-sm font-bold text-ink-2">
          {ngettext(
            "Delivers in %{count} neighborhood · up to %{km} km",
            "Delivers in %{count} neighborhoods · up to %{km} km",
            MapSet.size(@included),
            km: format_km(@radius_m),
            count: MapSet.size(@included)
          )}
        </p>

        <button
          type="submit"
          id="save-delivery-area"
          class="fixed inset-x-5 bottom-24 z-40 min-h-12 rounded-full bg-ink font-bold text-white shadow-nav md:static md:w-fit md:px-8"
        >
          {gettext("Save delivery area")}
        </button>
      </form>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PlacePoint">
        export default {
          mounted() {
            this.el.addEventListener("click", () => {
              if (!navigator.geolocation) return this.pushEvent("point_failed", {})
              this.el.disabled = true
              navigator.geolocation.getCurrentPosition(
                pos => {
                  this.el.disabled = false
                  this.pushEvent("set_point", {lat: pos.coords.latitude, lng: pos.coords.longitude})
                },
                () => {
                  this.el.disabled = false
                  this.pushEvent("point_failed", {})
                },
                {enableHighAccuracy: true, timeout: 15000, maximumAge: 0}
              )
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end

  defp format_km(meters), do: :erlang.float_to_binary(meters / 1000, decimals: 1)
  defp format_coord(value), do: :erlang.float_to_binary(value, decimals: 5)
end
