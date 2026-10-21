defmodule FreguesiaWeb.Admin.AdsLive do
  @moduledoc """
  Own ads waiting for moderation (PRD §7). Approving publishes the place's promotion
  and its details-page ad together. Rejecting needs a reason, which is audited.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Sponsorships

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: gettext("Ads")) |> load()}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    case Sponsorships.approve(id, socket.assigns.operator) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, gettext("Ad approved.")) |> load()}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, gettext("This ad was already decided.")) |> load()}
    end
  end

  def handle_event("reject", %{"ad" => %{"id" => id, "reason" => reason}}, socket) do
    case Sponsorships.reject(id, socket.assigns.operator, reason) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, gettext("Ad rejected.")) |> load()}

      {:error, :reason_required} ->
        {:noreply, put_flash(socket, :error, gettext("Write the reason to reject this ad."))}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, gettext("This ad was already decided.")) |> load()}
    end
  end

  defp load(socket) do
    ads = Sponsorships.list_pending()
    assign(socket, ads: ads, empty?: ads == [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} operator={@operator}>
      <div class="flex flex-col gap-6">
        <h1 class="text-2xl font-extrabold tracking-tight">{gettext("Ads")}</h1>

        <div :if={@empty?} id="no-pending-ads" class="rounded-card bg-white p-6 text-sm text-ink-2">
          {gettext("No ads waiting for review.")}
        </div>

        <article
          :for={ad <- @ads}
          id={"ad-#{ad.id}"}
          class="flex flex-col gap-4 rounded-card bg-white p-5 shadow-card"
        >
          <div>
            <p class="text-xs font-bold uppercase tracking-wide text-muted">
              {ad.place.name} · {ad.place.neighborhood.name}
            </p>
            <h2 class="mt-1 text-lg font-extrabold text-ink">{ad.promotion.title}</h2>
            <p :if={ad.promotion.body} class="mt-1 text-sm text-ink-2">{ad.promotion.body}</p>
            <p class="mt-2 text-xs text-muted">
              {gettext("From %{from} to %{to}",
                from: Calendar.strftime(ad.starts_at, "%d/%m"),
                to: Calendar.strftime(ad.ends_at, "%d/%m")
              )}
            </p>
          </div>

          <div class="flex flex-col gap-3 md:flex-row md:items-end">
            <button
              type="button"
              id={"approve-ad-#{ad.id}"}
              phx-click="approve"
              phx-value-id={ad.id}
              class="min-h-11 rounded-full bg-ink px-5 font-bold text-white"
            >
              {gettext("Approve")}
            </button>

            <.form
              for={%{}}
              as={:ad}
              id={"reject-ad-form-#{ad.id}"}
              phx-submit="reject"
              class="flex flex-1 flex-col gap-2 md:flex-row"
            >
              <input type="hidden" name="ad[id]" value={ad.id} />
              <input
                type="text"
                name="ad[reason]"
                placeholder={gettext("Reason for rejecting")}
                class="h-11 flex-1 rounded-full border border-line px-4 text-sm"
              />
              <button
                type="submit"
                id={"reject-ad-#{ad.id}"}
                class="min-h-11 rounded-full border border-line px-5 font-bold text-ink"
              >
                {gettext("Reject")}
              </button>
            </.form>
          </div>
        </article>
      </div>
    </Layouts.admin>
    """
  end
end
