defmodule FreguesiaWeb.SignupLive do
  @moduledoc """
  Place signup in 3 steps (PRD §6):

    1. Business details
    2. 6-digit code sent to WhatsApp
    3. Success screen: the place only appears after human approval
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.{Catalog, RateLimit, Verification}
  alias FreguesiaWeb.DeviceSession
  alias Phoenix.HTML.Form

  @impl true
  def mount(_params, session, socket) do
    segments = Catalog.list_segments()

    {:ok,
     socket
     |> assign(
       page_title: gettext("Register a place"),
       client_keys: DeviceSession.rate_limit_keys(session),
       step: 1,
       segments: segments,
       neighborhoods: Catalog.list_pilot_neighborhoods(),
       restaurant_id: restaurant_segment_id(segments),
       form: to_form(Verification.change_signup(%{}), as: :signup),
       code_form: to_form(%{"code" => ""}, as: :code),
       place: nil,
       delivery: nil,
       code_error: nil,
       code_notice: nil
     )}
  end

  @impl true
  def handle_event("validate", %{"signup" => params}, socket) do
    changeset = Verification.change_signup(params)
    {:noreply, assign(socket, form: to_form(changeset, as: :signup, action: :validate))}
  end

  def handle_event("save", %{"signup" => params}, socket) do
    case Verification.submit_signup(
           params,
           socket.assigns.current_business_account.id,
           socket.assigns.client_keys
         ) do
      {:ok, place, delivery} ->
        {:noreply,
         socket
         |> assign(step: 2, place: place, delivery: delivery, code_error: nil, code_notice: nil)}

      {:error, :rate_limited} ->
        {:noreply, put_flash(socket, :error, rate_limited_message())}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :signup, action: :insert))}
    end
  end

  def handle_event("confirm_code", %{"code" => %{"code" => code}}, socket) do
    case Verification.confirm_code(socket.assigns.place.id, String.trim(code)) do
      {:ok, _request} ->
        {:noreply, assign(socket, step: 3)}

      {:error, reason} ->
        {:noreply,
         assign(socket,
           code_error: code_error_message(reason),
           code_form: to_form(%{"code" => ""}, as: :code)
         )}
    end
  end

  def handle_event("resend_code", _params, socket) do
    case Verification.resend_code(socket.assigns.place.id, socket.assigns.client_keys) do
      {:ok, _code} ->
        {:noreply, assign(socket, code_error: nil, code_notice: gettext("We sent a new code."))}

      {:error, :too_soon} ->
        {:noreply,
         assign(socket, code_error: gettext("Wait 60 seconds before requesting another code."))}

      {:error, :rate_limited} ->
        {:noreply, assign(socket, code_error: rate_limited_message(), code_notice: nil)}

      {:error, _delivery_failed} ->
        {:noreply,
         assign(socket,
           code_error: gettext("We still can't send it. Try again in a moment.")
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <p class="text-xs font-bold uppercase tracking-wide text-muted">
        {gettext("Step %{step} of 3", step: @step)}
      </p>
      <div class="mt-3 mb-8">
        <FreguesiaWeb.Components.two_line_title
          first={gettext("Register your")}
          second={gettext("place.")}
        />
      </div>

      <.step_data
        :if={@step == 1}
        form={@form}
        segments={@segments}
        neighborhoods={@neighborhoods}
        restaurant_id={@restaurant_id}
      />
      <.step_code
        :if={@step == 2}
        place={@place}
        delivery={@delivery}
        code_form={@code_form}
        code_error={@code_error}
        code_notice={@code_notice}
      />
      <.step_done :if={@step == 3} place={@place} />
    </Layouts.app>
    """
  end

  attr :form, :any, required: true
  attr :segments, :list, required: true
  attr :neighborhoods, :list, required: true
  attr :restaurant_id, :any, required: true

  defp step_data(assigns) do
    selected_segment = Form.input_value(assigns.form, :segment_id)
    # Without a registered restaurant segment, nil == nil must not enable the field.
    restaurant? = not is_nil(assigns.restaurant_id) and selected_segment == assigns.restaurant_id
    categories = categories_for(assigns.segments, selected_segment)
    selected_coverage = Form.input_value(assigns.form, :coverage_ids) || []

    assigns =
      assign(assigns,
        restaurant?: restaurant?,
        categories: categories,
        selected_coverage: selected_coverage
      )

    ~H"""
    <.form
      for={@form}
      id="signup-form"
      phx-change="validate"
      phx-submit="save"
      class="flex flex-col gap-1"
    >
      <.input
        field={@form[:name]}
        type="text"
        label={gettext("Business name")}
        autocomplete="organization"
        placeholder={gettext("E.g.: Pizzaria do Zé")}
      />

      <.input
        field={@form[:segment_id]}
        type="select"
        label={gettext("Type")}
        prompt={gettext("Choose")}
        options={Enum.map(@segments, &{&1.name, &1.id})}
      />

      <.input
        :if={@restaurant?}
        field={@form[:category_id]}
        type="select"
        label={gettext("Type of food")}
        prompt={gettext("Choose")}
        options={Enum.map(@categories, &{&1.name, &1.id})}
      />

      <.input
        field={@form[:whatsapp]}
        type="tel"
        label={gettext("Business WhatsApp")}
        placeholder="(31) 99999-9999"
        inputmode="tel"
        autocomplete="tel"
      />

      <.input
        field={@form[:neighborhood_id]}
        type="select"
        label={gettext("Business neighborhood")}
        prompt={gettext("Choose")}
        options={Enum.map(@neighborhoods, &{&1.name, &1.id})}
      />

      <.input
        field={@form[:delivery_mode]}
        type="select"
        label={gettext("Delivery")}
        options={[{gettext("Own delivery"), "own"}, {gettext("Partner courier"), "partner"}]}
      />

      <fieldset class="mb-3">
        <legend class="mb-2 ml-1 text-sm font-semibold text-ink-2">
          {gettext("Neighborhoods served")}
        </legend>
        <div class="grid grid-cols-2 gap-2">
          <label
            :for={neighborhood <- @neighborhoods}
            class="flex cursor-pointer items-center gap-2 rounded-full border border-line bg-white px-4 py-2.5 text-sm font-semibold text-ink-2 has-[:checked]:border-ink has-[:checked]:bg-ink has-[:checked]:text-white"
          >
            <input
              type="checkbox"
              name="signup[coverage_ids][]"
              value={neighborhood.id}
              checked={neighborhood.id in @selected_coverage}
              class="sr-only"
            />
            {neighborhood.name}
          </label>
        </div>
        <.error :for={
          msg <- Enum.map(@form[:coverage_ids].errors, &FreguesiaWeb.CoreComponents.translate_error/1)
        }>
          {msg}
        </.error>
      </fieldset>

      <.input
        field={@form[:offer_text]}
        type="text"
        label={gettext("Offer for direct orders (optional)")}
        placeholder="Ex.: 10% off no pedido direto"
        maxlength="80"
      />
      <p class="-mt-2 mb-3 ml-1 text-xs text-muted">
        {gettext("Up to 80 characters. Don't mention other apps: the offer goes through moderation.")}
      </p>

      <.input
        field={@form[:accept_terms]}
        type="checkbox"
        label={gettext("I have read and accept the terms of use and the privacy policy")}
      />

      <div class="mt-4">
        <.button type="submit" id="signup-submit" class="w-full">{gettext("Continue")}</.button>
      </div>
    </.form>
    """
  end

  attr :place, :any, required: true
  attr :delivery, :atom, required: true
  attr :code_form, :any, required: true
  attr :code_error, :string, default: nil
  attr :code_notice, :string, default: nil

  defp step_code(assigns) do
    ~H"""
    <div class="flex flex-col gap-5">
      <p class="text-base text-ink-2">
        {gettext("We sent a 6-digit code to the WhatsApp ending in")} <span class="font-bold text-ink">{String.slice(@place.whatsapp_e164, -4..-1//1)}</span>.
      </p>

      <.warning_box :if={@delivery == :failed}>
        {gettext(
          "We couldn't send the code right now. We'll send it shortly; if it doesn't arrive, request it again in a little while."
        )}
      </.warning_box>

      <.warning_box :if={@code_error}>{@code_error}</.warning_box>

      <p :if={@code_notice} class="text-sm font-semibold text-ink-2">{@code_notice}</p>

      <.form for={@code_form} id="code-form" phx-submit="confirm_code" class="flex flex-col gap-1">
        <.input
          field={@code_form[:code]}
          type="text"
          label={gettext("Code")}
          inputmode="numeric"
          autocomplete="one-time-code"
          maxlength="6"
          placeholder="000000"
          id="code-input"
        />
        <div class="mt-3 flex flex-col gap-3">
          <.button type="submit" id="confirm-code">{gettext("Confirm")}</.button>
          <.button type="button" variant="outline" id="resend-code" phx-click="resend_code">
            {gettext("Resend code")}
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :place, :any, required: true

  defp step_done(assigns) do
    ~H"""
    <div id="signup-done" class="flex flex-col gap-5">
      <div class="rounded-card bg-sand p-6">
        <p class="text-lg font-extrabold text-ink">
          {gettext("We received the registration of %{name}.", name: @place.name)}
        </p>
        <p class="mt-2 text-sm text-ink-2">
          {gettext(
            "Under review, up to 1 business day. The answer arrives on this number's WhatsApp."
          )}
        </p>
      </div>

      <p class="text-sm text-muted">
        {gettext(
          "We only appear in the catalog after approval. You don't need to do anything else right now."
        )}
      </p>

      <.link
        navigate={~p"/areas/savassi"}
        class="text-sm font-bold text-ink underline underline-offset-4"
      >
        {gettext("Back to the catalog")}
      </.link>
    </div>
    """
  end

  defp restaurant_segment_id(segments) do
    case Enum.find(segments, &(&1.key == "restaurants")) do
      nil -> nil
      segment -> segment.id
    end
  end

  defp categories_for(_segments, nil), do: []

  defp categories_for(segments, segment_id) do
    case Enum.find(segments, &(&1.id == segment_id)) do
      nil -> []
      segment -> segment.categories
    end
  end

  defp code_error_message({:invalid_code, remaining}),
    do:
      ngettext(
        "Wrong code. You have %{count} more attempt.",
        "Wrong code. You have %{count} more attempts.",
        remaining,
        count: remaining
      )

  defp code_error_message(:too_many_attempts),
    do: gettext("Too many attempts. Request a new code.")

  defp code_error_message(:expired), do: gettext("This code has expired. Request a new one.")
  defp code_error_message(:no_code), do: gettext("Request a code to continue.")

  defp rate_limited_message do
    gettext("Too many codes requested. Wait %{minutes} minutes and try again.",
      minutes: RateLimit.window_minutes(:verification_code)
    )
  end
end
