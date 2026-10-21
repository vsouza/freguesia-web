defmodule FreguesiaWeb.BusinessAccountLive do
  @moduledoc """
  Business account home (PRD §6): the places this account manages, their delivery
  areas, and the way to register another place. Requires a signed-in account.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.{Business, DeliveryAreas}

  @impl true
  def mount(_params, _session, socket) do
    places = Business.places_for(socket.assigns.current_business_account)

    {:ok,
     socket
     |> assign(page_title: gettext("Your places"), places: places, summaries: summaries(places))}
  end

  defp summaries(places) do
    Map.new(places, fn place ->
      area = DeliveryAreas.get_for_place(place.id)

      summary =
        if area,
          do: %{radius_m: area.radius_m, covered: DeliveryAreas.coverage_count(place.id)}

      {place.id, summary}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_neighborhood={@current_neighborhood}>
      <FreguesiaWeb.Components.two_line_title first={gettext("Your")} second={gettext("places")} />

      <p class="mt-4 text-sm text-ink-2">
        {gettext("Signed in as %{email}.",
          email: @current_business_account.email || @current_business_account.name || ""
        )}
      </p>

      <ul :if={@places != []} id="business-places" class="mt-6 flex flex-col gap-4">
        <li :for={place <- @places} id={"business-place-#{place.id}"}>
          <article class="flex flex-col gap-3 rounded-card bg-white p-5 shadow-card">
            <div class="flex items-start justify-between gap-3">
              <div>
                <h2 class="text-lg font-extrabold text-ink">{place.name}</h2>
                <p class="text-sm text-muted">{place.neighborhood.name}</p>
              </div>
              <span class="rounded-full bg-sand px-3 py-1 text-xs font-bold text-ink-2">
                {status_label(place.status)}
              </span>
            </div>

            <p :if={@summaries[place.id]} class="text-sm text-ink-2">
              {ngettext(
                "Delivers in %{count} neighborhood · up to %{km} km",
                "Delivers in %{count} neighborhoods · up to %{km} km",
                @summaries[place.id].covered,
                km: format_km(@summaries[place.id].radius_m),
                count: @summaries[place.id].covered
              )}
            </p>
            <p :if={!@summaries[place.id]} class="text-sm font-bold text-tomato-600">
              {gettext("Set your delivery area to show up to customers.")}
            </p>

            <div class="flex flex-wrap gap-2">
              <.link
                navigate={~p"/business/places/#{place.id}/delivery-area"}
                class="inline-flex min-h-11 w-fit items-center rounded-full bg-ink px-5 font-bold text-white"
              >
                {gettext("Delivery area")}
              </.link>
              <.link
                navigate={~p"/business/places/#{place.id}/ad"}
                class="inline-flex min-h-11 w-fit items-center rounded-full border border-line px-5 font-bold text-ink"
              >
                {gettext("Ad on the place page")}
              </.link>
            </div>
          </article>
        </li>
      </ul>

      <div :if={@places == []} id="no-places" class="mt-6">
        <FreguesiaWeb.Components.empty_state title={gettext("No places yet")}>
          {gettext("Register your place to get a verified WhatsApp number in the catalog.")}
        </FreguesiaWeb.Components.empty_state>
      </div>

      <.link
        navigate={~p"/business/register"}
        id="register-place"
        class="mt-6 inline-flex min-h-12 w-fit items-center rounded-full bg-ink px-6 font-bold text-white"
      >
        {gettext("Register a place")}
      </.link>

      <.link
        href={~p"/business/session"}
        method="delete"
        id="business-sign-out"
        class="mt-10 text-center text-sm font-bold text-muted underline"
      >
        {gettext("Sign out")}
      </.link>
    </Layouts.app>
    """
  end

  defp status_label(:verified), do: gettext("Verified")
  defp status_label(:pending), do: gettext("Under review")
  defp status_label(:needs_changes), do: gettext("Changes requested")
  defp status_label(:rejected), do: gettext("Not approved")
  defp status_label(:paused), do: gettext("Paused")
  defp status_label(_), do: gettext("Unavailable")

  defp format_km(meters), do: :erlang.float_to_binary(meters / 1000, decimals: 1)
end
