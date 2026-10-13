defmodule FreguesiaWeb.Admin.PlaceLive do
  @moduledoc """
  One place in the backoffice (PRD §7): pause for today, resume, change category,
  remove with a reason, review reports held by batch review, and read the audit trail.
  """
  use FreguesiaWeb, :live_view

  import Ecto.Query, only: [from: 2]

  alias Freguesia.{Admin, Backoffice, Repo}
  alias Freguesia.Reports.Report

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Backoffice.get_place(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Place not found."))
         |> push_navigate(to: ~p"/admin/places")}

      place ->
        {:ok, socket |> assign(page_title: place.name) |> load(place)}
    end
  end

  @impl true
  def handle_event("pause", _params, socket) do
    {:ok, place} = Backoffice.pause_today(socket.assigns.place, socket.assigns.operator)

    {:noreply,
     socket |> put_flash(:info, gettext("Paused until the end of today.")) |> load(place)}
  end

  def handle_event("resume", _params, socket) do
    {:ok, place} = Backoffice.resume(socket.assigns.place, socket.assigns.operator)
    {:noreply, socket |> put_flash(:info, gettext("Back to serving.")) |> load(place)}
  end

  def handle_event("reassign", %{"category" => %{"id" => id}}, socket) do
    case Backoffice.reassign_category(socket.assigns.place, socket.assigns.operator, id) do
      {:ok, place} ->
        {:noreply, socket |> put_flash(:info, gettext("Category updated.")) |> load(place)}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("This category does not belong to the place's segment.")
         )}
    end
  end

  def handle_event("remove", %{"remove" => %{"reason" => reason}}, socket) do
    case Backoffice.remove(socket.assigns.place, socket.assigns.operator, reason) do
      {:ok, _place} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Place removed from the catalog."))
         |> push_navigate(to: ~p"/admin/places")}

      {:error, :reason_required} ->
        {:noreply, put_flash(socket, :error, gettext("Write the reason to remove this place."))}
    end
  end

  def handle_event("release", %{"id" => id}, socket) do
    report = Repo.get!(Report, id)
    {:ok, _} = Backoffice.release_report(report, socket.assigns.operator)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Report released to the statistics."))
     |> load(socket.assigns.place)}
  end

  defp load(socket, place) do
    place = Repo.preload(place, [:segment, :category, :neighborhood], force: true)

    assign(socket,
      place: place,
      categories: segment_categories(place.segment_id),
      stats: Backoffice.place_stats(place.id),
      held: Backoffice.flagged_reports(place.id),
      audit: Admin.audit_entries("place", place.id)
    )
  end

  defp segment_categories(segment_id) do
    Repo.all(
      from c in Freguesia.Catalog.Category, where: c.segment_id == ^segment_id, order_by: c.name
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} operator={@operator}>
      <div class="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <div class="flex flex-col gap-6">
          <section class="rounded-card border border-line bg-white p-6">
            <.link navigate={~p"/admin/places"} class="text-sm font-bold text-ink-2">
              {gettext("Back to places")}
            </.link>
            <h1 class="mt-2 text-2xl font-extrabold">{@place.name}</h1>
            <p class="text-sm text-ink-2">
              {@place.segment.name} · {@place.neighborhood.name} · {@place.whatsapp_e164} · {gettext(
                "Status"
              )}: {to_string(@place.status)}
            </p>

            <div class="mt-5 flex flex-wrap gap-3">
              <button
                :if={!@place.paused_until}
                id="pause"
                phx-click="pause"
                class="rounded-full border border-ink px-5 py-2 font-bold"
              >
                {gettext("Not serving today")}
              </button>
              <button
                :if={@place.paused_until}
                id="resume"
                phx-click="resume"
                class="rounded-full border border-ink px-5 py-2 font-bold"
              >
                {gettext("Back to serving")}
              </button>
            </div>

            <form id="reassign-form" phx-submit="reassign" class="mt-5 flex flex-wrap items-end gap-3">
              <label class="flex flex-col text-sm font-bold text-ink-2">
                {gettext("Category")}
                <select
                  name="category[id]"
                  class="mt-1 h-11 rounded-full border border-line bg-white px-4 font-normal"
                >
                  <option
                    :for={category <- @categories}
                    value={category.id}
                    selected={category.id == @place.category_id}
                  >
                    {category.name}
                  </option>
                </select>
              </label>
              <button type="submit" class="h-11 rounded-full bg-ink px-5 font-bold text-white">
                {gettext("Save category")}
              </button>
            </form>
          </section>

          <section id="stats" class="rounded-card border border-line bg-white p-6">
            <h2 class="text-lg font-extrabold">{gettext("Reports")}</h2>
            <div class="mt-3 grid gap-3 sm:grid-cols-2">
              <div
                :for={
                  {window, label} <- [
                    {"30d", gettext("Last 30 days")},
                    {"90d", gettext("Last 90 days")}
                  ]
                }
                class="rounded-tile bg-sand p-4 text-sm"
              >
                <p class="font-bold">{label}</p>
                <p>
                  {gettext("Opens")}: {@stats[window].opens} · {gettext("Answers")}: {@stats[window].responses} · {gettext(
                    "Worked"
                  )}: {@stats[window].worked}
                </p>
              </div>
            </div>
          </section>

          <section id="held-reports" class="rounded-card border border-line bg-white p-6">
            <h2 class="text-lg font-extrabold">{gettext("Held by batch review")}</h2>
            <p :if={@held == []} class="mt-2 text-sm text-ink-2">{gettext("Nothing held.")}</p>
            <ul class="mt-3 flex flex-col gap-2">
              <li
                :for={report <- @held}
                id={"held-#{report.id}"}
                class="flex flex-wrap items-center justify-between gap-3 text-sm"
              >
                <span>
                  {gettext("Answered at")} {Calendar.strftime(report.answered_at, "%d/%m/%Y %H:%M")} · {report.outcome}
                </span>
                <button
                  phx-click="release"
                  phx-value-id={report.id}
                  class="rounded-full border border-ink px-4 py-1 font-bold"
                >
                  {gettext("Release")}
                </button>
              </li>
            </ul>
          </section>

          <section class="rounded-card border border-line bg-white p-6">
            <h2 class="text-lg font-extrabold">{gettext("Remove place")}</h2>
            <form id="remove-form" phx-submit="remove" class="mt-3 flex flex-col gap-3">
              <textarea
                name="remove[reason]"
                rows="2"
                required
                placeholder={gettext("Reason (required)")}
                class="rounded-tile border border-line p-3"
              ></textarea>
              <button
                type="submit"
                class="self-start rounded-full border border-tomato-600 px-5 py-2 font-bold text-tomato-600"
              >
                {gettext("Remove from catalog")}
              </button>
            </form>
          </section>
        </div>

        <aside id="audit" class="rounded-card border border-line bg-white p-6">
          <h2 class="text-lg font-extrabold">{gettext("History")}</h2>
          <ol class="mt-3 flex flex-col gap-3 text-sm">
            <li :for={entry <- @audit} class="border-l-2 border-line pl-3">
              <p class="font-bold">{entry.action}</p>
              <p class="text-ink-2">{Calendar.strftime(entry.inserted_at, "%d/%m/%Y %H:%M")}</p>
            </li>
            <li :if={@audit == []} class="text-ink-2">{gettext("No changes yet.")}</li>
          </ol>
        </aside>
      </div>
    </Layouts.admin>
    """
  end
end
