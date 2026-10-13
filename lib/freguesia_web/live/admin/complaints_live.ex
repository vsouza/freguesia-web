defmodule FreguesiaWeb.Admin.ComplaintsLive do
  @moduledoc "Open complaints (PRD §7). Closing one with a resolution puts the WhatsApp button back."
  use FreguesiaWeb, :live_view

  alias Freguesia.{Backoffice, Repo}
  alias Freguesia.Reports.Complaint

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: gettext("Complaints")) |> load()}
  end

  @impl true
  def handle_event("close", %{"complaint" => %{"id" => id, "resolution" => resolution}}, socket) do
    complaint = Repo.get!(Complaint, id)

    case Backoffice.close_complaint(complaint, socket.assigns.operator, resolution) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, gettext("Complaint closed.")) |> load()}

      {:error, :reason_required} ->
        {:noreply, put_flash(socket, :error, gettext("Write the resolution to close this case."))}
    end
  end

  defp load(socket) do
    complaints = Backoffice.list_complaints()
    assign(socket, complaints: complaints, empty?: complaints == [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} operator={@operator}>
      <div class="flex flex-col gap-6">
        <h1 class="text-2xl font-extrabold tracking-tight">{gettext("Complaints")}</h1>

        <div :if={@empty?} class="rounded-card bg-white p-6 text-sm text-ink-2">
          {gettext("No open complaints.")}
        </div>

        <div
          :for={complaint <- @complaints}
          id={"complaint-#{complaint.id}"}
          class="rounded-card border border-line bg-white p-5"
        >
          <p class="font-bold">
            <.link navigate={~p"/admin/places/#{complaint.place.id}"} class="underline">
              {complaint.place.name}
            </.link>
            · {complaint.place.neighborhood.name}
          </p>
          <p class="text-sm text-ink-2">
            {gettext("Reason")}: {to_string(complaint.reason)} · {gettext("Source")}: {to_string(
              complaint.source
            )} · {Calendar.strftime(complaint.inserted_at, "%d/%m/%Y %H:%M")}
          </p>
          <p :if={complaint.details} class="mt-2 text-sm">{complaint.details}</p>

          <form
            id={"close-#{complaint.id}"}
            phx-submit="close"
            class="mt-4 flex flex-wrap items-end gap-3"
          >
            <input type="hidden" name="complaint[id]" value={complaint.id} />
            <label class="flex grow flex-col text-sm font-bold text-ink-2">
              {gettext("Resolution")}
              <input
                name="complaint[resolution]"
                required
                class="mt-1 h-11 rounded-full border border-line px-4 font-normal"
              />
            </label>
            <button type="submit" class="h-11 rounded-full bg-ink px-5 font-bold text-white">
              {gettext("Close case")}
            </button>
          </form>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
