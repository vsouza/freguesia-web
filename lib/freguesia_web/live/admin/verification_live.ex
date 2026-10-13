defmodule FreguesiaWeb.Admin.VerificationLive do
  @moduledoc """
  Review of a request: automatic checks, card preview and the three decisions
  (approve, request adjustments, reject). Opening the request already puts it under review.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Catalog.OpeningHours
  alias Freguesia.Verification

  defp adjustment_templates do
    [
      {gettext("Photo"),
       gettext("Send a photo of the storefront or counter so it appears with an image.")},
      {gettext("Profile name"),
       gettext(
         "The WhatsApp Business profile name does not match the business name. Adjust one of them."
       )},
      {gettext("Neighborhood"),
       gettext(
         "This neighborhood is outside the pilot area. Choose a Belo Horizonte neighborhood from the list."
       )}
    ]
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Verification.get_request(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Request not found."))
         |> push_navigate(to: ~p"/admin/verifications")}

      request ->
        {:ok, request} = Verification.start_review(request, socket.assigns.operator)

        {:ok,
         socket
         |> assign(
           page_title: request.place.name,
           request: request,
           checks: Verification.evaluate_checks(request),
           preview: preview_place(request.place),
           templates: adjustment_templates(),
           decision: decision_form(""),
           reason_form: decision_form("")
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"decision" => params}, socket) do
    {:noreply, assign(socket, decision: decision_form(params["note"] || params["reason"] || ""))}
  end

  def handle_event("approve", %{"decision" => %{"note" => note}}, socket) do
    decide(
      socket,
      Verification.approve(socket.assigns.request, socket.assigns.operator, blank_to_nil(note)),
      gettext("Place approved and published.")
    )
  end

  def handle_event("request_changes", %{"decision" => %{"reason" => reason}}, socket) do
    decide(
      socket,
      Verification.request_changes(socket.assigns.request, socket.assigns.operator, reason),
      gettext("Adjustment request sent to the business.")
    )
  end

  def handle_event("reject", %{"decision" => %{"reason" => reason}}, socket) do
    decide(
      socket,
      Verification.reject(socket.assigns.request, socket.assigns.operator, reason),
      gettext("Registration rejected.")
    )
  end

  def handle_event("use_template", %{"text" => text}, socket) do
    {:noreply, assign(socket, reason_form: decision_form(text))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} operator={@operator}>
      <.link
        navigate={~p"/admin/verifications"}
        class="mb-4 inline-flex items-center gap-1 text-sm font-bold text-ink-2 hover:text-ink"
      >
        <.icon name="hero-arrow-left-mini" class="size-4" /> {gettext("Queue")}
      </.link>

      <div class="grid gap-6 lg:grid-cols-[1fr_20rem]">
        <div class="flex flex-col gap-6">
          <section class="rounded-card border border-line bg-white p-6">
            <p class="text-xs font-bold uppercase tracking-wide text-muted">
              {gettext("Registration")}
            </p>
            <h1 class="mt-1 text-2xl font-extrabold tracking-tight">{@request.place.name}</h1>

            <dl class="mt-5 grid gap-4 text-sm sm:grid-cols-2">
              <div>
                <dt class="font-semibold text-muted">{gettext("Type")}</dt>
                <dd class="font-bold">
                  {@request.place.segment.name}{if @request.place.category,
                    do: " · #{@request.place.category.name}"}
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-muted">WhatsApp</dt>
                <dd class="font-bold">{@request.place.whatsapp_e164}</dd>
              </div>
              <div>
                <dt class="font-semibold text-muted">{gettext("Business neighborhood")}</dt>
                <dd class="font-bold">{@request.place.neighborhood.name}</dd>
              </div>
              <div>
                <dt class="font-semibold text-muted">{gettext("Delivery")}</dt>
                <dd class="font-bold">
                  {if @request.place.delivery_mode == :own,
                    do: gettext("Own"),
                    else: gettext("Partner courier")}
                </dd>
              </div>
              <div class="sm:col-span-2">
                <dt class="font-semibold text-muted">{gettext("Neighborhoods served")}</dt>
                <dd class="font-bold">{coverage_names(@request.place)}</dd>
              </div>
              <div :if={pending_offer(@request.place)} class="sm:col-span-2">
                <dt class="font-semibold text-muted">{gettext("Proposed offer")}</dt>
                <dd class="font-bold">{pending_offer(@request.place).text}</dd>
              </div>
            </dl>
          </section>

          <section class="rounded-card border border-line bg-white p-6">
            <h2 class="text-lg font-extrabold">{gettext("Automatic checks")}</h2>
            <ul id="checks" class="mt-4 divide-y divide-line">
              <li
                :for={{key, value} <- check_rows(@checks)}
                id={"check-#{key}"}
                class="flex items-start gap-3 py-3 text-sm"
              >
                <.icon
                  name={check_icon(value)}
                  class={["mt-0.5 size-5 flex-none", check_color(value)]}
                />
                <div>
                  <p class="font-bold">{check_label(key)}</p>
                  <p class="text-muted">{check_hint(key, value)}</p>
                </div>
              </li>
            </ul>
          </section>

          <section class="rounded-card border border-line bg-white p-6">
            <h2 class="text-lg font-extrabold">{gettext("Decision")}</h2>

            <div class="mt-5 grid gap-8 md:grid-cols-2">
              <.form
                for={@decision}
                id="approve-form"
                phx-submit="approve"
                phx-change="validate"
                class="flex flex-col gap-2"
              >
                <.input
                  field={@decision[:note]}
                  id="approve-note"
                  type="textarea"
                  label={gettext("Internal note")}
                  placeholder={gettext("Required if any check did not pass")}
                />
                <.button type="submit" id="approve-submit">{gettext("Approve and publish")}</.button>
              </.form>

              <div class="flex flex-col gap-6">
                <.form
                  for={@reason_form}
                  id="changes-form"
                  phx-submit="request_changes"
                  class="flex flex-col gap-2"
                >
                  <div class="flex flex-wrap gap-2">
                    <button
                      :for={{label, text} <- @templates}
                      type="button"
                      phx-click="use_template"
                      phx-value-text={text}
                      class="rounded-full bg-sand px-3 py-1.5 text-xs font-bold text-ink-2 hover:bg-line"
                    >
                      {label}
                    </button>
                  </div>
                  <.input
                    field={@reason_form[:reason]}
                    id="changes-reason"
                    type="textarea"
                    label={gettext("Reason for adjustment")}
                  />
                  <.button type="submit" variant="outline" id="changes-submit">
                    {gettext("Request adjustment")}
                  </.button>
                </.form>

                <.form
                  for={@reason_form}
                  id="reject-form"
                  phx-submit="reject"
                  class="flex flex-col gap-2"
                >
                  <.input
                    field={@reason_form[:reason]}
                    id="reject-reason"
                    type="textarea"
                    label={gettext("Reason for rejection")}
                  />
                  <.button type="submit" variant="outline" id="reject-submit">
                    {gettext("Reject registration")}
                  </.button>
                </.form>
              </div>
            </div>
          </section>
        </div>

        <aside class="flex flex-col gap-3">
          <p class="text-xs font-bold uppercase tracking-wide text-muted">
            {gettext("How it appears in the catalog")}
          </p>
          <FreguesiaWeb.Components.place_card place={@preview} />
          <p class="text-xs text-muted">{gettext("Preview. It only goes live after approval.")}</p>
        </aside>
      </div>
    </Layouts.admin>
    """
  end

  defp decide(socket, result, success_message) do
    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, success_message)
         |> push_navigate(to: ~p"/admin/verifications")}

      {:error, :checks_incomplete} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("A check did not pass. Write an internal note to approve anyway.")
         )}

      {:error, :reason_required} ->
        {:noreply, put_flash(socket, :error, gettext("Write the reason to continue."))}

      {:error, :already_decided} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("This request has already been decided."))
         |> push_navigate(to: ~p"/admin/verifications")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, gettext("I couldn't save the decision. Try again."))}
    end
  end

  defp decision_form(text), do: to_form(%{"note" => text, "reason" => text}, as: :decision)

  defp preview_place(place) do
    %{
      place
      | status: :verified,
        hours_status: OpeningHours.status(place.opening_hours, nil),
        offers: []
    }
  end

  defp pending_offer(place) do
    Enum.find(place.offers || [], &(&1.status == :pending))
  end

  defp coverage_names(place) do
    case place.coverage do
      [] -> gettext("Only the business's neighborhood")
      coverage -> coverage |> Enum.map_join(", ", & &1.neighborhood.name)
    end
  end

  defp check_rows(checks) do
    order = ~w(code profile_name in_pilot no_complaints)

    Enum.map(order, fn key -> {key, Map.get(checks, key, "pending")} end)
  end

  defp check_label("code"), do: gettext("WhatsApp code confirmed")
  defp check_label("profile_name"), do: gettext("WhatsApp Business profile name")
  defp check_label("in_pilot"), do: gettext("Neighborhood within the pilot")
  defp check_label("no_complaints"), do: gettext("No open complaint")

  defp check_hint("profile_name", "pending"),
    do: gettext("We haven't read the profile yet. Check it and approve with a note.")

  defp check_hint("profile_name", "fail"),
    do: gettext("The profile name does not match the name provided.")

  defp check_hint(_key, "ok"), do: gettext("All good.")
  defp check_hint(_key, "fail"), do: gettext("Did not pass. Check before approving.")
  defp check_hint(_key, _), do: gettext("Pending.")

  defp check_icon("ok"), do: "hero-check-circle"
  defp check_icon("fail"), do: "hero-x-circle"
  defp check_icon(_), do: "hero-clock"

  defp check_color("ok"), do: "text-ink"
  defp check_color("fail"), do: "text-tomato-600"
  defp check_color(_), do: "text-muted"

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
