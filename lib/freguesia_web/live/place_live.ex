defmodule FreguesiaWeb.PlaceLive do
  @moduledoc """
  Place details (PRD §5): photo (category placeholder), status, offer
  approved, proof of savings and the button to order on WhatsApp.

  The WhatsApp loop lives here: the button goes through `/places/:slug/whatsapp` (which records the
  opening), and when the tab regains focus, the return sheet asks whether the order
  worked. The sheet state machine lives on the server.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.{Catalog, Events, Reports}
  alias Freguesia.Catalog.ColorMap
  alias Freguesia.Reports.{Savings, Stats}
  alias FreguesiaWeb.Components

  @visible_statuses [:verified, :paused]

  @fail_reasons %{
    "app_only" => :app_only,
    "no_coverage" => :no_coverage,
    "no_answer" => :no_answer,
    "wrong_or_scam" => :wrong_or_scam
  }

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    place = Catalog.get_place_by_slug(slug)

    if place && place.status in @visible_statuses do
      device_id = session["device_id"]

      if connected?(socket) do
        Events.track("place_viewed", %{place_slug: slug}, device_id)
      end

      {:ok,
       socket
       |> assign(
         page_title: place.name,
         place: place,
         device_id: device_id,
         ip24: session["ip24"],
         offer: Catalog.active_offer(place),
         colors:
           ColorMap.for_key(
             (place.category && place.category.color_key) || place.segment.color_key
           ),
         stats: Stats.for_place(place.id),
         hidden?: Reports.whatsapp_hidden?(place.id),
         sheet: nil,
         report_open?: false
       )
       |> then(&if(connected?(socket), do: open_pending_sheet(&1), else: &1))}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("This place is not in the catalog."))
       |> push_navigate(to: ~p"/areas/savassi")}
    end
  end

  ## Return sheet

  @impl true
  def handle_event("returned", _params, socket), do: {:noreply, open_pending_sheet(socket)}

  def handle_event("toggle_report", _params, socket) do
    {:noreply, update(socket, :report_open?, &(!&1))}
  end

  def handle_event("report", %{"report" => params}, socket) do
    %{place: place, device_id: device_id} = socket.assigns
    reason = if params["reason"] == "other", do: :other, else: :wrong_or_scam
    details = blank_to_nil(params["details"])

    {:ok, _complaint} = Reports.open_complaint(place.id, :form, reason, details)
    Events.track("report_submitted", %{place_slug: place.slug, source: "form"}, device_id)

    {:noreply,
     socket
     |> assign(report_open?: false, hidden?: Reports.whatsapp_hidden?(place.id))
     |> put_flash(:info, gettext("Thanks. We will review this number."))}
  end

  def handle_event("later", _params, socket) do
    # "Answer later": closes it, but the opening stays pending for 2 h.
    {:noreply, assign(socket, sheet: nil)}
  end

  def handle_event("worked", _params, socket) do
    {:noreply, update_sheet(socket, %{step: :savings})}
  end

  def handle_event("failed", _params, socket) do
    {:noreply, update_sheet(socket, %{step: :reason})}
  end

  def handle_event("band", %{"band" => band}, socket) do
    answer(socket, %{outcome: :worked, band: band})
  end

  def handle_event("reason", %{"reason" => reason}, socket) do
    case Map.fetch(@fail_reasons, reason) do
      {:ok, reason} -> answer(socket, %{outcome: :failed, reason: reason})
      :error -> {:noreply, put_flash(socket, :error, gettext("Choose a reason from the list."))}
    end
  end

  # Opens the sheet when there is a pending opening of up to 2 h and the sheet is closed.
  defp open_pending_sheet(%{assigns: %{sheet: nil}} = socket) do
    %{place: place, device_id: device_id} = socket.assigns

    case device_id && Reports.pending_open(place.id, device_id) do
      nil ->
        socket

      open ->
        Events.track("return_prompt_shown", %{place_slug: place.slug}, device_id)
        assign(socket, sheet: %{open_id: open.id, step: :ask})
    end
  end

  defp open_pending_sheet(socket), do: socket

  defp answer(%{assigns: %{sheet: %{open_id: open_id}}} = socket, attrs) do
    %{device_id: device_id, ip24: ip24, place: place} = socket.assigns

    case Reports.answer(open_id, attrs, %{device_id: device_id, ip24_hash: ip24}) do
      {:ok, _report} ->
        Events.track(
          "report_submitted",
          %{place_slug: place.slug, outcome: attrs.outcome},
          device_id
        )

        {:noreply,
         socket
         |> assign(sheet: nil, hidden?: Reports.whatsapp_hidden?(place.id))
         |> put_flash(:info, gettext("Thanks. Helps the next customer decide."))}

      {:error, reason} when reason in [:already_answered, :expired] ->
        {:noreply,
         socket
         |> assign(sheet: nil)
         |> put_flash(:error, gettext("This question is no longer open."))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("I couldn't save your answer. Try again."))}
    end
  end

  defp answer(socket, _attrs), do: {:noreply, socket}

  defp update_sheet(%{assigns: %{sheet: sheet}} = socket, changes) when is_map(sheet) do
    assign(socket, sheet: Map.merge(sheet, changes))
  end

  defp update_sheet(socket, _changes), do: socket

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="return-prompt" phx-hook=".ReturnPrompt" class="hidden"></div>

      <.link
        navigate={~p"/areas/#{@place.neighborhood.slug}"}
        class="mb-4 inline-flex w-fit items-center gap-1 text-sm font-bold text-ink-2 hover:text-ink"
      >
        <.icon name="hero-arrow-left-mini" class="size-4" /> {@place.neighborhood.name}
      </.link>

      <%= if @place.photo_key do %>
        <img
          src={~p"/photos/#{@place.photo_key}"}
          alt={gettext("Photo of %{name}", name: @place.name)}
          class="aspect-[16/9] w-full rounded-card object-cover"
        />
      <% else %>
        <div
          class={["flex aspect-[16/9] items-end rounded-card p-5", @colors.tint]}
          role="img"
          aria-label={gettext("Photo of %{name} not uploaded yet", name: @place.name)}
        >
          <span class={["text-sm font-bold uppercase tracking-wide", @colors.accent]}>
            {(@place.category && @place.category.name) || @place.segment.name}
          </span>
        </div>
      <% end %>

      <section class="mt-6 flex flex-col gap-4">
        <div class="flex flex-wrap items-center gap-2">
          <Components.verified_badge :if={@place.status == :verified} />
          <span class="text-sm text-ink-2">
            <Components.hours_label status={@place.hours_status} />
          </span>
        </div>

        <h1 class="text-3xl font-extrabold leading-tight tracking-tight text-ink">{@place.name}</h1>

        <div :if={@offer} id="offer" class="rounded-card border border-line p-5">
          <p class="text-xs font-bold uppercase tracking-wide text-muted">{gettext("Offer")}</p>
          <p class="mt-1 text-base font-bold text-ink">{@offer.text}</p>
          <p class="mt-2 text-xs text-muted">
            {gettext("Provided by the business · updated on %{date}",
              date: format_date(@offer.approved_at)
            )}
          </p>
        </div>

        <.proof_section stats={@stats} place={@place} />

        <div class="rounded-card bg-sand p-5 text-sm text-ink-2">
          <p class="font-bold text-ink">{gettext("Delivery")}</p>
          <p class="mt-1">
            {gettext("%{mode}. Arrangements are made directly with the business.",
              mode: delivery_label(@place.delivery_mode)
            )}
          </p>
        </div>

        <div id="about-direct" class="rounded-card border border-line p-5 text-sm text-ink-2">
          <p class="font-bold text-ink">{gettext("About ordering direct")}</p>
          <p class="mt-1">
            {gettext(
              "Freguesia does not take the order. You talk to the business on WhatsApp, and price, payment and delivery are agreed there."
            )}
          </p>
        </div>

        <div id="report" class="text-sm">
          <%= if @report_open? do %>
            <form
              id="report-form"
              phx-submit="report"
              class="flex flex-col gap-3 rounded-card border border-line p-5"
            >
              <p class="font-bold text-ink">{gettext("Report this number")}</p>
              <label for="report-reason" class="text-xs font-bold text-ink-2">
                {gettext("What is wrong?")}
              </label>
              <select
                id="report-reason"
                name="report[reason]"
                class="h-11 rounded-full border border-line px-4"
              >
                <option value="wrong_or_scam">{gettext("Wrong number or scam")}</option>
                <option value="other">{gettext("Something else")}</option>
              </select>
              <label for="report-details" class="text-xs font-bold text-ink-2">
                {gettext("Details (optional)")}
              </label>
              <textarea
                id="report-details"
                name="report[details]"
                maxlength="280"
                rows="3"
                class="rounded-tile border border-line p-3"
              ></textarea>
              <button
                type="submit"
                id="report-submit"
                class="inline-flex min-h-11 items-center justify-center rounded-full border border-ink px-5 font-bold text-ink"
              >
                {gettext("Send report")}
              </button>
            </form>
          <% else %>
            <button
              type="button"
              id="report-open"
              phx-click="toggle_report"
              class="font-bold text-ink-2 underline underline-offset-4"
            >
              {gettext("Report number")}
            </button>
          <% end %>
        </div>
      </section>

      <div class="h-24" aria-hidden="true" />

      <div class="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-white/95 px-4 pb-24 pt-4 backdrop-blur">
        <div class="mx-auto flex max-w-md flex-col gap-2 md:max-w-3xl">
          <%= cond do %>
            <% @hidden? -> %>
              <span
                id="whatsapp-cta"
                aria-disabled="true"
                class="inline-flex min-h-12 items-center justify-center rounded-full border border-line px-6 text-base font-bold text-muted"
              >
                {gettext("Number under review")}
              </span>
            <% @place.status == :verified and @place.hours_status != {:paused} -> %>
              <%!-- New tab: the page stays open and the sheet appears when the tab regains focus. --%>
              <a
                href={~p"/places/#{@place.slug}/whatsapp"}
                target="_blank"
                rel="noopener"
                id="whatsapp-cta"
                class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-ink px-6 text-base font-bold text-white transition duration-150 hover:bg-ink-2 active:scale-[0.98]"
              >
                <.icon name="hero-chat-bubble-left-ellipsis" class="size-5" /> {gettext(
                  "Order on WhatsApp"
                )}
              </a>
            <% true -> %>
              <span
                id="whatsapp-cta"
                aria-disabled="true"
                class="inline-flex min-h-12 items-center justify-center rounded-full border border-line px-6 text-base font-bold text-muted"
              >
                {gettext("Not taking orders today")}
              </span>
          <% end %>
        </div>
      </div>

      <.bottom_sheet :if={@sheet} id="return-sheet" title={sheet_title(@sheet.step)}>
        <div class="flex flex-col gap-3">
          <%= case @sheet.step do %>
            <% :ask -> %>
              <button
                id="sheet-yes"
                phx-click="worked"
                class="rounded-full bg-ink px-6 py-3 font-bold text-white"
              >
                {gettext("Yes")}
              </button>
              <button
                id="sheet-no"
                phx-click="failed"
                class="rounded-full border border-ink px-6 py-3 font-bold text-ink"
              >
                {gettext("No")}
              </button>
              <button
                id="sheet-later"
                phx-click="later"
                class="text-sm font-bold text-muted underline"
              >
                {gettext("Answer later")}
              </button>
            <% :savings -> %>
              <button
                :for={{key, _mid, label} <- Savings.bands()}
                id={"band-#{key}"}
                phx-click="band"
                phx-value-band={key}
                class="rounded-full border border-line px-6 py-3 text-left font-bold text-ink hover:bg-sand"
              >
                {label}
              </button>
              <button
                id="band-not_compared"
                phx-click="band"
                phx-value-band="not_compared"
                class="rounded-full border border-line px-6 py-3 text-left font-bold text-muted hover:bg-sand"
              >
                {gettext("Didn't compare")}
              </button>
            <% :reason -> %>
              <button
                id="reason-app_only"
                phx-click="reason"
                phx-value-reason="app_only"
                class="rounded-full border border-line px-6 py-3 text-left font-bold text-ink hover:bg-sand"
              >
                {gettext("Only takes orders through the app")}
              </button>
              <button
                id="reason-no_coverage"
                phx-click="reason"
                phx-value-reason="no_coverage"
                class="rounded-full border border-line px-6 py-3 text-left font-bold text-ink hover:bg-sand"
              >
                {gettext("Doesn't deliver to my neighborhood")}
              </button>
              <button
                id="reason-no_answer"
                phx-click="reason"
                phx-value-reason="no_answer"
                class="rounded-full border border-line px-6 py-3 text-left font-bold text-ink hover:bg-sand"
              >
                {gettext("Didn't respond")}
              </button>
              <button
                id="reason-wrong_or_scam"
                phx-click="reason"
                phx-value-reason="wrong_or_scam"
                class="rounded-full border border-saffron-800 px-6 py-3 text-left font-bold text-saffron-800 hover:bg-saffron-100"
              >
                {gettext("Wrong number or scam")}
              </button>
          <% end %>
        </div>
      </.bottom_sheet>
    </Layouts.app>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".ReturnPrompt">
      export default {
        mounted() {
          this.onVisible = () => {
            if (document.visibilityState === "visible") this.pushEvent("returned", {})
          }
          document.addEventListener("visibilitychange", this.onVisible)
        },
        destroyed() {
          document.removeEventListener("visibilitychange", this.onVisible)
        }
      }
    </script>
    """
  end

  attr :stats, :map, required: true
  attr :place, :any, required: true

  defp proof_section(assigns) do
    month = assigns.stats["30d"]
    quarter = assigns.stats["90d"]
    n = quarter.savings_hist |> Map.values() |> Enum.sum()

    assigns = assign(assigns, month: month, quarter: quarter, n: n)

    ~H"""
    <div class="grid gap-4">
      <div id="proof-funcionou" class="rounded-card border border-line p-5">
        <p class="text-xs font-bold uppercase tracking-wide text-muted">{gettext("Worked")}</p>
        <div class="mt-2">
          <Components.funcionou_bar worked={@month.worked} responses={@month.responses} />
        </div>
      </div>

      <div id="proof-savings" class="rounded-card bg-ink p-5 text-white">
        <p class="text-xs font-bold uppercase tracking-wide text-white/70">
          {gettext("Reported savings")}
        </p>

        <%= if @n >= 10 do %>
          <p class="mt-2 text-4xl font-extrabold text-gold">
            {round_avg(@quarter.savings_avg)}%
          </p>
          <p class="mt-1 text-sm">{gettext("less, on average, than on the apps")}</p>
          <p class="mt-2 text-xs text-white/70">
            {gettext("Reported by %{count} regulars in the last 90 days. May vary.", count: @n)}
          </p>
          <div class="mt-4 text-ink-2">
            <div class="rounded-tile bg-white p-3">
              <Components.savings_histogram hist={@quarter.savings_hist} avg={@quarter.savings_avg} />
            </div>
          </div>
        <% else %>
          <p class="mt-2 text-sm">
            {gettext("Few reports so far (%{count}). Ordered direct? Tell us what you paid.",
              count: @n
            )}
          </p>
          <.link
            navigate={~p"/places/#{@place.slug}/whatsapp"}
            class="mt-3 inline-flex text-sm font-bold text-gold underline underline-offset-4"
          >
            {gettext("Order and tell us")}
          </.link>
        <% end %>

        <details class="mt-4 text-xs text-white/80">
          <summary class="cursor-pointer font-bold">{gettext("How we calculate")}</summary>
          <p class="mt-2">
            {gettext(
              "Each \"Yes\" answer becomes a report with the midpoint of the chosen band (same price = 0%, up to 10% = 5%, 10 to 20% = 15%, 20 to 30% = 25%, more than 30% = 35%). The average is simple, only from valid reports from the last 90 days, and only shows with 10 or more reports. \"Didn't compare\" is not counted."
            )}
          </p>
        </details>
      </div>
    </div>
    """
  end

  defp sheet_title(:ask), do: gettext("Did you order directly?")
  defp sheet_title(:savings), do: gettext("How much did it cost compared to the apps?")
  defp sheet_title(:reason), do: gettext("What happened?")

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp round_avg(nil), do: 0
  defp round_avg(avg), do: avg |> Decimal.round(0) |> Decimal.to_integer()

  defp delivery_label(:own), do: gettext("Own delivery")
  defp delivery_label(:partner), do: gettext("Partner courier")

  defp format_date(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y")
end
