defmodule FreguesiaWeb.SignupLive do
  @moduledoc """
  Place signup in 3 steps (PRD §6):

    1. Business details
    2. 6-digit code sent to WhatsApp
    3. Success screen: the place only appears after human approval
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.{Catalog, Verification}
  alias Phoenix.HTML.Form

  @impl true
  def mount(_params, _session, socket) do
    segments = Catalog.list_segments()

    {:ok,
     socket
     |> assign(
       page_title: "Cadastrar lugar",
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
    case Verification.submit_signup(params) do
      {:ok, place, delivery} ->
        {:noreply,
         socket
         |> assign(step: 2, place: place, delivery: delivery, code_error: nil, code_notice: nil)}

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
    case Verification.resend_code(socket.assigns.place.id) do
      {:ok, _code} ->
        {:noreply, assign(socket, code_error: nil, code_notice: "Enviamos um novo código.")}

      {:error, :too_soon} ->
        {:noreply, assign(socket, code_error: "Espere 60 segundos para pedir outro código.")}

      {:error, _delivery_failed} ->
        {:noreply,
         assign(socket,
           code_error: "Ainda não conseguimos enviar. Tente de novo em instantes."
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <p class="text-xs font-bold uppercase tracking-wide text-muted">Passo {@step} de 3</p>
      <div class="mt-3 mb-8">
        <FreguesiaWeb.Components.two_line_title first="Cadastre seu" second="lugar." />
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
        label="Nome do negócio"
        autocomplete="organization"
        placeholder="Ex.: Pizzaria do Zé"
      />

      <.input
        field={@form[:segment_id]}
        type="select"
        label="Tipo"
        prompt="Escolha"
        options={Enum.map(@segments, &{&1.name, &1.id})}
      />

      <.input
        :if={@restaurant?}
        field={@form[:category_id]}
        type="select"
        label="Tipo de comida"
        prompt="Escolha"
        options={Enum.map(@categories, &{&1.name, &1.id})}
      />

      <.input
        field={@form[:whatsapp]}
        type="tel"
        label="WhatsApp do negócio"
        placeholder="(31) 99999-9999"
        inputmode="tel"
        autocomplete="tel"
      />

      <.input
        field={@form[:neighborhood_id]}
        type="select"
        label="Bairro do negócio"
        prompt="Escolha"
        options={Enum.map(@neighborhoods, &{&1.name, &1.id})}
      />

      <.input
        field={@form[:delivery_mode]}
        type="select"
        label="Entrega"
        options={[{"Entrega própria", "own"}, {"Motoboy parceiro", "partner"}]}
      />

      <fieldset class="mb-3">
        <legend class="mb-2 ml-1 text-sm font-semibold text-ink-2">Bairros atendidos</legend>
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
        label="Vantagem para quem pede direto (opcional)"
        placeholder="Ex.: 10% off no pedido direto"
        maxlength="80"
      />
      <p class="-mt-2 mb-3 ml-1 text-xs text-muted">
        Até 80 caracteres. Não cite outros apps: a vantagem passa por moderação.
      </p>

      <.input
        field={@form[:accept_terms]}
        type="checkbox"
        label="Li e aceito os termos de uso e a política de privacidade"
      />

      <div class="mt-4">
        <.button type="submit" id="signup-submit" class="w-full">Continuar</.button>
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
        Enviamos um código de 6 dígitos para o WhatsApp terminado em <span class="font-bold text-ink">{String.slice(@place.whatsapp_e164, -4..-1//1)}</span>.
      </p>

      <.warning_box :if={@delivery == :failed}>
        Não conseguimos enviar o código agora. Vamos mandar em instantes; se não chegar, peça de novo daqui a pouco.
      </.warning_box>

      <.warning_box :if={@code_error}>{@code_error}</.warning_box>

      <p :if={@code_notice} class="text-sm font-semibold text-ink-2">{@code_notice}</p>

      <.form for={@code_form} id="code-form" phx-submit="confirm_code" class="flex flex-col gap-1">
        <.input
          field={@code_form[:code]}
          type="text"
          label="Código"
          inputmode="numeric"
          autocomplete="one-time-code"
          maxlength="6"
          placeholder="000000"
          id="code-input"
        />
        <div class="mt-3 flex flex-col gap-3">
          <.button type="submit" id="confirm-code">Confirmar</.button>
          <.button type="button" variant="outline" id="resend-code" phx-click="resend_code">
            Reenviar código
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
        <p class="text-lg font-extrabold text-ink">Recebemos o cadastro de {@place.name}.</p>
        <p class="mt-2 text-sm text-ink-2">
          Em análise, até 1 dia útil. A resposta chega no WhatsApp desse número.
        </p>
      </div>

      <p class="text-sm text-muted">
        Só aparecemos no catálogo depois da aprovação. Você não precisa fazer mais nada agora.
      </p>

      <.link
        navigate={~p"/bairro/savassi"}
        class="text-sm font-bold text-ink underline underline-offset-4"
      >
        Voltar ao catálogo
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
      "Código incorreto. Você tem mais #{remaining} tentativa#{if remaining == 1, do: "", else: "s"}."

  defp code_error_message(:too_many_attempts), do: "Tentativas esgotadas. Peça um código novo."
  defp code_error_message(:expired), do: "Esse código expirou. Peça um novo."
  defp code_error_message(:no_code), do: "Peça um código para continuar."
end
