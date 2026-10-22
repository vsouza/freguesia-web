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

    socket
    |> assign(empty?: ads == [])
    |> stream(:ads, Enum.map(ads, &row/1), reset: true, dom_id: &"ad-#{&1.ad.id}")
  end

  # Each ad carries its own reject form, so the reason typed for one ad never leaks to another.
  defp row(ad), do: %{ad: ad, reject_form: to_form(%{"id" => ad.id, "reason" => ""}, as: :ad)}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} operator={@operator}>
      <div class="flex flex-col gap-6">
        <h1 class="text-2xl font-extrabold tracking-tight">{gettext("Ads")}</h1>

        <div :if={@empty?} id="no-pending-ads" class="rounded-card bg-white p-6 text-sm text-ink-2">
          {gettext("No ads waiting for review.")}
        </div>

        <div id="ads" phx-update="stream" class="flex flex-col gap-6">
          <article
            :for={{dom_id, row} <- @streams.ads}
            id={dom_id}
            class="flex flex-col gap-4 rounded-card bg-white p-5 shadow-card"
          >
            <div>
              <p class="text-xs font-bold uppercase tracking-wide text-muted">
                {row.ad.place.name} · {row.ad.place.neighborhood.name}
              </p>
              <h2 class="mt-1 text-lg font-extrabold text-ink">{row.ad.promotion.title}</h2>
              <p :if={row.ad.promotion.body} class="mt-1 text-sm text-ink-2">
                {row.ad.promotion.body}
              </p>
              <p class="mt-2 text-xs text-muted">
                {gettext("From %{from} to %{to}",
                  from: Calendar.strftime(row.ad.starts_at, "%d/%m"),
                  to: Calendar.strftime(row.ad.ends_at, "%d/%m")
                )}
              </p>
            </div>

            <div class="flex flex-col gap-3 md:flex-row md:items-end">
              <button
                type="button"
                id={"approve-ad-#{row.ad.id}"}
                phx-click="approve"
                phx-value-id={row.ad.id}
                class="min-h-11 rounded-full bg-ink px-5 font-bold text-white"
              >
                {gettext("Approve")}
              </button>

              <.form
                for={row.reject_form}
                id={"reject-ad-form-#{row.ad.id}"}
                phx-submit="reject"
                class="flex flex-1 flex-col gap-2 md:flex-row"
              >
                <input type="hidden" name="ad[id]" value={row.ad.id} />
                <.input
                  field={row.reject_form[:reason]}
                  id={"reject-reason-#{row.ad.id}"}
                  type="text"
                  label={gettext("Reason for rejecting")}
                  class="h-11 flex-1 rounded-full border border-line px-4 text-sm"
                />
                <button
                  type="submit"
                  id={"reject-ad-#{row.ad.id}"}
                  class="min-h-11 rounded-full border border-line px-5 font-bold text-ink"
                >
                  {gettext("Reject")}
                </button>
              </.form>
            </div>
          </article>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
