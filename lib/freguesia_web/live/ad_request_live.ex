defmodule FreguesiaWeb.AdRequestLive do
  @moduledoc """
  Own ad request for a place of the account (PRD §6). Asks for a promotion with its text
  and a period of up to 7 days. It shows on the place's details page once an operator
  approves it. Free during the pilot.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.{Business, Sponsorships}

  @impl true
  def mount(%{"id" => place_id}, _session, socket) do
    case Business.get_place_for(socket.assigns.current_business_account, place_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("That place is not in your account."))
         |> push_navigate(to: ~p"/business/account")}

      place ->
        {:ok,
         socket
         |> assign(
           page_title: gettext("Ad on the place page"),
           place: place,
           day_options: day_options(),
           form: new_form()
         )
         |> stream_requests()}
    end
  end

  @impl true
  def handle_event("validate", %{"ad" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: :ad))}
  end

  def handle_event("save", %{"ad" => params}, socket) do
    case Sponsorships.request_own_ad(socket.assigns.place, params) do
      {:ok, _sponsorship} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Sent for review. It shows up once approved."))
         |> assign(form: new_form())
         |> stream_requests()}

      {:error, errors} ->
        form =
          to_form(params,
            as: :ad,
            errors: Enum.map(errors, fn {field, message} -> {field, {message, []}} end),
            action: :validate
          )

        {:noreply, assign(socket, form: form)}
    end
  end

  defp new_form, do: to_form(%{"title" => "", "body" => "", "days" => "3"}, as: :ad)

  defp stream_requests(socket) do
    requests = Sponsorships.list_for_place(socket.assigns.place.id)

    socket
    |> assign(requests_empty?: requests == [])
    |> stream(:requests, requests, reset: true, dom_id: &"ad-request-#{&1.id}")
  end

  defp day_options do
    for days <- 1..Sponsorships.max_days() do
      {ngettext("%{count} day", "%{count} days", days, count: days), Integer.to_string(days)}
    end
  end

  defp status_label(:pending), do: gettext("Under review")
  defp status_label(:approved), do: gettext("Approved")
  defp status_label(:rejected), do: gettext("Not approved")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_neighborhood={@current_neighborhood}>
      <FreguesiaWeb.Components.two_line_title
        first={gettext("Ad on the")}
        second={gettext("place page.")}
      />

      <p class="mt-2 text-sm text-muted">{@place.name}</p>

      <p class="mt-4 text-sm text-ink-2">
        {gettext(
          "The ad shows on your place page, labeled as paid by the place, for up to 7 days. We review it before it goes live."
        )}
      </p>

      <.form
        for={@form}
        id="ad-form"
        phx-change="validate"
        phx-submit="save"
        class="mt-6 flex flex-col gap-4"
      >
        <.input field={@form[:title]} type="text" label={gettext("Offer title")} />
        <.input field={@form[:body]} type="textarea" label={gettext("Details (optional)")} />
        <.input field={@form[:days]} type="select" label={gettext("Show for")} options={@day_options} />

        <button
          type="submit"
          id="submit-ad"
          class="min-h-12 rounded-full bg-ink font-bold text-white"
        >
          {gettext("Send for review")}
        </button>
      </.form>

      <section :if={!@requests_empty?} class="mt-10 flex flex-col gap-3">
        <h2 class="text-sm font-bold uppercase tracking-wide text-muted">
          {gettext("Your requests")}
        </h2>
        <div id="ad-requests" phx-update="stream" class="flex flex-col gap-3">
          <article
            :for={{dom_id, request} <- @streams.requests}
            id={dom_id}
            class="flex items-center justify-between gap-3 rounded-tile bg-white p-4 shadow-card"
          >
            <span class="font-semibold text-ink">{request.promotion.title}</span>
            <span class="rounded-full bg-sand px-3 py-1 text-xs font-bold text-ink-2">
              {status_label(request.status)}
            </span>
          </article>
        </div>
      </section>

      <.link
        navigate={~p"/business/account"}
        class="mt-10 text-sm font-bold text-muted underline"
      >
        {gettext("Back to your places")}
      </.link>
    </Layouts.app>
    """
  end
end
