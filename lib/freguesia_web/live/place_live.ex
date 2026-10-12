defmodule FreguesiaWeb.PlaceLive do
  @moduledoc """
  Detalhes de um lugar (PRD §5): foto (placeholder da categoria), status, oferta
  aprovada, provas de economia e o botão para pedir no WhatsApp.

  O loop do WhatsApp mora aqui: o botão passa por `/r/:slug` (que registra a
  abertura), e quando a aba volta ao foco, a folha de retorno pergunta se o pedido
  funcionou. A máquina de estados da folha fica no servidor.
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
         sheet: nil
       )
       |> then(&if(connected?(socket), do: open_pending_sheet(&1), else: &1))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Esse lugar não está no catálogo.")
       |> push_navigate(to: ~p"/bairro/savassi")}
    end
  end

  ## Folha de retorno

  @impl true
  def handle_event("returned", _params, socket), do: {:noreply, open_pending_sheet(socket)}

  def handle_event("later", _params, socket) do
    # "Responder depois": fecha, mas a abertura continua pendente até 2 h.
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
      :error -> {:noreply, put_flash(socket, :error, "Escolha um motivo da lista.")}
    end
  end

  # Abre a folha se houver abertura pendente de até 2 h e a folha ainda estiver fechada.
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
         |> put_flash(:info, "Valeu. Ajuda o próximo freguês a decidir.")}

      {:error, reason} when reason in [:already_answered, :expired] ->
        {:noreply,
         socket
         |> assign(sheet: nil)
         |> put_flash(:error, "Essa pergunta já não está aberta.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Não consegui salvar sua resposta. Tente de novo.")}
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
        navigate={~p"/bairro/#{@place.neighborhood.slug}"}
        class="mb-4 inline-flex w-fit items-center gap-1 text-sm font-bold text-ink-2 hover:text-ink"
      >
        <.icon name="hero-arrow-left-mini" class="size-4" /> {@place.neighborhood.name}
      </.link>

      <div
        class={["flex aspect-[16/9] items-end rounded-card p-5", @colors.tint]}
        role="img"
        aria-label={"Foto de #{@place.name} ainda não enviada"}
      >
        <span class={["text-sm font-bold uppercase tracking-wide", @colors.accent]}>
          {(@place.category && @place.category.name) || @place.segment.name}
        </span>
      </div>

      <section class="mt-6 flex flex-col gap-4">
        <div class="flex flex-wrap items-center gap-2">
          <Components.verified_badge :if={@place.status == :verified} />
          <span class="text-sm text-ink-2">
            <Components.hours_label status={@place.hours_status} />
          </span>
        </div>

        <h1 class="text-3xl font-extrabold leading-tight tracking-tight text-ink">{@place.name}</h1>

        <div :if={@offer} id="offer" class="rounded-card border border-line p-5">
          <p class="text-xs font-bold uppercase tracking-wide text-muted">Vantagem</p>
          <p class="mt-1 text-base font-bold text-ink">{@offer.text}</p>
          <p class="mt-2 text-xs text-muted">
            Informado pelo restaurante · atualizado em {format_date(@offer.approved_at)}
          </p>
        </div>

        <.proof_section stats={@stats} place={@place} />

        <div class="rounded-card bg-sand p-5 text-sm text-ink-2">
          <p class="font-bold text-ink">Entrega</p>
          <p class="mt-1">
            {delivery_label(@place.delivery_mode)}. O combinado é direto com o restaurante.
          </p>
        </div>
      </section>

      <div class="h-24" aria-hidden="true" />

      <div class="fixed inset-x-0 bottom-0 z-40 border-t border-line bg-white/95 px-4 py-4 backdrop-blur">
        <div class="mx-auto flex max-w-md flex-col gap-2 md:max-w-3xl">
          <%= cond do %>
            <% @hidden? -> %>
              <span
                id="whatsapp-cta"
                aria-disabled="true"
                class="inline-flex min-h-12 items-center justify-center rounded-full border border-line px-6 text-base font-bold text-muted"
              >
                Número em revisão
              </span>
            <% @place.status == :verified and @place.hours_status != {:paused} -> %>
              <%!-- Nova aba: a página continua aberta e a folha aparece quando a aba volta ao foco. --%>
              <a
                href={~p"/r/#{@place.slug}"}
                target="_blank"
                rel="noopener"
                id="whatsapp-cta"
                class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-ink px-6 text-base font-bold text-white transition duration-150 hover:bg-ink-2 active:scale-[0.98]"
              >
                <.icon name="hero-chat-bubble-left-ellipsis" class="size-5" /> Pedir no WhatsApp
              </a>
            <% true -> %>
              <span
                id="whatsapp-cta"
                aria-disabled="true"
                class="inline-flex min-h-12 items-center justify-center rounded-full border border-line px-6 text-base font-bold text-muted"
              >
                Sem atender hoje
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
                Sim
              </button>
              <button
                id="sheet-no"
                phx-click="failed"
                class="rounded-full border border-ink px-6 py-3 font-bold text-ink"
              >
                Não
              </button>
              <button
                id="sheet-later"
                phx-click="later"
                class="text-sm font-bold text-muted underline"
              >
                Responder depois
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
                Não comparei
              </button>
            <% :reason -> %>
              <button
                id="reason-app_only"
                phx-click="reason"
                phx-value-reason="app_only"
                class="rounded-full border border-line px-6 py-3 text-left font-bold text-ink hover:bg-sand"
              >
                Só atende pelo app
              </button>
              <button
                id="reason-no_coverage"
                phx-click="reason"
                phx-value-reason="no_coverage"
                class="rounded-full border border-line px-6 py-3 text-left font-bold text-ink hover:bg-sand"
              >
                Não entrega no meu bairro
              </button>
              <button
                id="reason-no_answer"
                phx-click="reason"
                phx-value-reason="no_answer"
                class="rounded-full border border-line px-6 py-3 text-left font-bold text-ink hover:bg-sand"
              >
                Não respondeu
              </button>
              <button
                id="reason-wrong_or_scam"
                phx-click="reason"
                phx-value-reason="wrong_or_scam"
                class="rounded-full border border-saffron-800 px-6 py-3 text-left font-bold text-saffron-800 hover:bg-saffron-100"
              >
                Número errado ou golpe
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
        <p class="text-xs font-bold uppercase tracking-wide text-muted">Pedido direto</p>
        <div class="mt-2">
          <Components.funcionou_bar worked={@month.worked} responses={@month.responses} />
        </div>
      </div>

      <div id="proof-savings" class="rounded-card bg-ink p-5 text-white">
        <p class="text-xs font-bold uppercase tracking-wide text-white/70">Economia relatada</p>

        <%= if @n >= 10 do %>
          <p class="mt-2 text-4xl font-extrabold text-gold">
            {round_avg(@quarter.savings_avg)}%
          </p>
          <p class="mt-1 text-sm">a menos, em média, do que nos apps</p>
          <p class="mt-2 text-xs text-white/70">
            Relatado por {@n} fregueses nos últimos 90 dias. Pode variar.
          </p>
          <div class="mt-4 text-ink-2">
            <div class="rounded-tile bg-white p-3">
              <Components.savings_histogram hist={@quarter.savings_hist} avg={@quarter.savings_avg} />
            </div>
          </div>
        <% else %>
          <p class="mt-2 text-sm">
            Poucos relatos até agora ({@n}). Pediu direto? Conte quanto pagou.
          </p>
          <.link
            navigate={~p"/r/#{@place.slug}"}
            class="mt-3 inline-flex text-sm font-bold text-gold underline underline-offset-4"
          >
            Pedir e contar
          </.link>
        <% end %>

        <details class="mt-4 text-xs text-white/80">
          <summary class="cursor-pointer font-bold">Como calculamos</summary>
          <p class="mt-2">
            Cada resposta "Sim" vira um relato com o ponto médio da faixa escolhida (mesmo preço = 0%,
            até 10% = 5%, 10 a 20% = 15%, 20 a 30% = 25%, mais de 30% = 35%). A média é simples,
            só dos relatos válidos dos últimos 90 dias, e só aparece com 10 ou mais relatos.
            "Não comparei" não entra na conta.
          </p>
        </details>
      </div>
    </div>
    """
  end

  defp sheet_title(:ask), do: "Conseguiu pedir direto?"
  defp sheet_title(:savings), do: "Quanto ficou em relação aos apps?"
  defp sheet_title(:reason), do: "O que aconteceu?"

  defp round_avg(nil), do: 0
  defp round_avg(avg), do: avg |> Decimal.round(0) |> Decimal.to_integer()

  defp delivery_label(:own), do: "Entrega própria"
  defp delivery_label(:partner), do: "Motoboy parceiro"

  defp format_date(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y")
end
