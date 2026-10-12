defmodule FreguesiaWeb.Components do
  @moduledoc """
  Componentes do design da Freguesia (PRD §12). Ficam separados de `CoreComponents`,
  que são o básico do Phoenix (formulários, botões, tabelas).
  """
  use Phoenix.Component
  use FreguesiaWeb, :verified_routes

  import FreguesiaWeb.CoreComponents, only: [icon: 1]

  alias Freguesia.Catalog.ColorMap
  alias Freguesia.Reports.{Savings, Stats}

  @doc """
  Card de um lugar na lista do bairro.

  Três estados (PRD §5):
    * verificado: fundo da categoria, selo, etiqueta da oferta se houver
    * não verificado: fundo `sand`, sem oferta, sem economia
    * fechado: o status "Fechado · abre às…" aparece no lugar do "Aberto"
  """
  attr :place, :any, required: true
  attr :class, :any, default: nil

  def place_card(assigns) do
    place = assigns.place
    verified? = place.status == :verified
    colors = if verified?, do: category_colors(place), else: ColorMap.neutral()
    # Regra 4 (PRD §4): no card só o resumo da oferta; sem resumo, nada aparece.
    offer = if verified?, do: Freguesia.Catalog.active_offer(place)

    assigns =
      assign(assigns,
        verified?: verified?,
        colors: colors,
        offer: offer,
        funcionou_text: funcionou_chip(place),
        economia_text: economia_chip(place)
      )

    ~H"""
    <.link
      navigate={~p"/lugar/#{@place.slug}"}
      id={"place-card-#{@place.slug}"}
      class={[
        "group relative flex flex-col gap-3 rounded-card p-5 shadow-card transition duration-150 hover:-translate-y-0.5 focus-visible:outline-2 focus-visible:outline-ink",
        @colors.tint,
        @class
      ]}
    >
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <p class={["text-xs font-bold uppercase tracking-wide", @colors.accent]}>
            {category_label(@place)}
          </p>
          <h3 class="mt-0.5 truncate text-lg font-extrabold leading-tight text-ink">
            {@place.name}
          </h3>
        </div>
        <.verified_badge :if={@verified?} />
      </div>

      <p class="text-sm text-ink-2">
        <.hours_label status={@place.hours_status} />
        <span class="text-muted">· {@place.neighborhood.name}</span>
      </p>

      <.not_verified_note :if={!@verified?} />

      <div :if={@verified? and is_list(@place.stats)} class="flex flex-wrap gap-2">
        <.proof_chip :if={@funcionou_text} text={@funcionou_text} />
        <.proof_chip :if={@economia_text} text={@economia_text} />
      </div>

      <.offer_tag :if={@offer && @offer.tag} text={@offer.tag} />
    </.link>
    """
  end

  @doc """
  Prova de que o pedido direto funciona: "Funcionou 31/33". Só aparece com ao menos
  1 resposta em 30 dias (PRD §8).
  """
  attr :text, :string, required: true

  def proof_chip(assigns) do
    ~H"""
    <span class="rounded-full bg-white/70 px-2.5 py-1 text-xs font-bold text-ink-2">{@text}</span>
    """
  end

  @doc "Selo Verificado. Único elemento em índigo (PRD §12)."
  def verified_badge(assigns) do
    ~H"""
    <span class="inline-flex flex-none items-center gap-1 rounded-full bg-indigo-100 px-2.5 py-1 text-xs font-bold text-indigo-800">
      <.icon name="hero-check-badge-mini" class="size-4" /> Verificado
    </span>
    """
  end

  @doc """
  Etiqueta inclinada com o resumo da oferta (regra 4: no card só o resumo).
  """
  attr :text, :string, required: true

  def offer_tag(assigns) do
    ~H"""
    <span class="inline-flex w-fit -rotate-2 items-center gap-1.5 rounded-tile bg-ink px-3 py-1.5 text-sm font-bold text-white shadow-tag">
      <.icon name="hero-tag-mini" class="size-4 text-gold" />
      {@text}
    </span>
    """
  end

  @doc "Estado de horário: aberto, fechado, pausado (PRD §8)."
  attr :status, :any, required: true

  def hours_label(assigns) do
    ~H"""
    <%= case @status do %>
      <% {:open, closes_at} -> %>
        <span class="font-bold text-ink">Aberto</span>
        <span class="ml-1 text-ink-2">· até {closes_at}</span>
      <% {:closed, nil} -> %>
        <span class="font-bold text-muted">Fechado</span>
      <% {:closed, opens_at} -> %>
        <span class="font-bold text-muted">Fechado</span>
        <span class="ml-1 text-muted">· abre às {opens_at}</span>
      <% {:paused} -> %>
        <span class="font-bold text-muted">Sem atender hoje</span>
    <% end %>
    """
  end

  defp not_verified_note(assigns) do
    ~H"""
    <p class="text-xs text-muted">Ainda não verificado pelo restaurante.</p>
    """
  end

  @doc """
  Folha inferior (retorno do WhatsApp, PRD §5). Sem fundo escuro: o foco fica nela.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  def bottom_sheet(assigns) do
    ~H"""
    <div
      id={@id}
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      class="fixed inset-x-0 bottom-0 z-50 mx-auto max-w-md rounded-t-sheet bg-white p-6 shadow-nav md:max-w-xl"
    >
      <div class="mx-auto mb-4 h-1.5 w-12 rounded-full bg-line" aria-hidden="true"></div>
      <h2 id={"#{@id}-title"} class="text-lg font-extrabold text-ink">{@title}</h2>
      <div class="mt-4">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  @doc """
  Histograma das cinco faixas de economia (PRD §8). A faixa da média fica destacada.
  """
  attr :hist, :map, required: true
  attr :avg, :any, required: true

  def savings_histogram(assigns) do
    total = assigns.hist |> Map.values() |> Enum.sum() |> max(1)
    highlight = Savings.band_for_average(assigns.avg && Decimal.to_float(assigns.avg))

    assigns =
      assign(assigns,
        total: total,
        highlight: highlight,
        bands: Savings.bands()
      )

    ~H"""
    <figure
      role="img"
      aria-label={"Distribuição da economia relatada. Faixa da média: #{Savings.label(@highlight)}."}
    >
      <ul class="flex flex-col gap-2">
        <li
          :for={{key, _mid, label} <- @bands}
          class="grid grid-cols-[7rem_1fr_2.5rem] items-center gap-3 text-xs"
        >
          <span class={[
            "font-semibold",
            key == @highlight && "text-ink",
            key != @highlight && "text-muted"
          ]}>
            {label}
          </span>
          <span class="h-2 overflow-hidden rounded-full bg-sand">
            <span
              class={[
                "block h-full rounded-full",
                key == @highlight && "bg-ink",
                key != @highlight && "bg-line"
              ]}
              style={"width: #{percent(Map.get(@hist, key, 0), @total)}%"}
            >
            </span>
          </span>
          <span class="text-right font-semibold text-ink-2">{Map.get(@hist, key, 0)}</span>
        </li>
      </ul>
    </figure>
    """
  end

  @doc """
  "Funcionou X/Y em 30 dias". Barra só com 5 ou mais respostas (PRD §8).
  """
  attr :worked, :integer, required: true
  attr :responses, :integer, required: true

  def funcionou_bar(assigns) do
    ~H"""
    <div>
      <p class="text-sm font-bold text-ink">
        <%= if @responses == 0 do %>
          Ainda sem respostas nos últimos 30 dias
        <% else %>
          Funcionou {@worked}/{@responses} em 30 dias
        <% end %>
      </p>
      <div
        :if={@responses >= 5}
        class="mt-2 h-2 overflow-hidden rounded-full bg-sand"
        aria-hidden="true"
      >
        <div class="h-full rounded-full bg-ink" style={"width: #{percent(@worked, @responses)}%"}>
        </div>
      </div>
    </div>
    """
  end

  @doc "Aviso em caixa de atenção (cor saffron)."
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def warning_box(assigns) do
    ~H"""
    <div class={["flex gap-3 rounded-tile bg-saffron-100 px-4 py-3 text-sm text-saffron-800", @class]}>
      <.icon name="hero-exclamation-triangle" class="mt-0.5 size-5 flex-none" />
      <div>{render_slot(@inner_block)}</div>
    </div>
    """
  end

  @doc "Estado vazio com uma ação opcional."
  attr :title, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class={["flex flex-col items-start gap-3 rounded-card bg-sand p-6", @class]}>
      <p class="text-lg font-extrabold text-ink">{@title}</p>
      <div :if={@inner_block != []} class="text-sm text-ink-2">{render_slot(@inner_block)}</div>
      <div :if={@action != []}>{render_slot(@action)}</div>
    </div>
    """
  end

  @doc "Título em dois tempos (PRD §12): linha 1 itálico 300, linha 2 negrito 800."
  attr :first, :string, required: true
  attr :second, :string, required: true

  def two_line_title(assigns) do
    ~H"""
    <h1 class="text-3xl leading-tight tracking-tight">
      <span class="block italic font-light text-ink-2">{@first}</span>
      <span class="block font-extrabold tracking-[-0.02em] text-ink">{@second}</span>
    </h1>
    """
  end

  @doc """
  QR code em SVG. O SVG vem de `EQRCode` a partir da URI do TOTP, nunca de entrada
  do usuário, por isso é seguro inseri-lo sem escape.
  """
  attr :svg, :string, required: true

  # sobelow_skip ["XSS.Raw"]
  def qr_code(assigns) do
    ~H"""
    {Phoenix.HTML.raw(@svg)}
    """
  end

  @doc """
  Link para o WhatsApp com a mensagem padrão (PRD §11). O número vem em E.164
  e o `wa.me` pede só os dígitos.
  """
  def whatsapp_url(place_name, whatsapp_e164) do
    digits = String.trim_leading(whatsapp_e164, "+")
    text = "Oi! Vi o #{place_name} na Freguesia e quero pedir direto."
    "https://wa.me/#{digits}?text=#{URI.encode(text, &URI.char_unreserved?/1)}"
  end

  defp funcionou_chip(place) do
    if is_list(place.stats) do
      stat = Stats.window(place, "30d")
      if stat.responses >= 1, do: "Funcionou #{stat.worked}/#{stat.responses}"
    end
  end

  defp economia_chip(place) do
    if is_list(place.stats) do
      stat = Stats.window(place, "90d")
      n = stat.savings_hist |> Map.values() |> Enum.sum()
      if n >= 10, do: "Economia média #{round_avg(stat.savings_avg)}%"
    end
  end

  defp round_avg(nil), do: 0
  defp round_avg(avg), do: avg |> Decimal.round(0) |> Decimal.to_integer()

  defp percent(_part, 0), do: 0
  defp percent(part, total), do: round(part * 100 / total)

  defp category_colors(%{category: %{color_key: key}}) when is_binary(key),
    do: ColorMap.for_key(key)

  defp category_colors(%{segment: %{color_key: key}}), do: ColorMap.for_key(key)
  defp category_colors(_place), do: ColorMap.neutral()

  defp category_label(%{category: %{name: name}}) when is_binary(name), do: name
  defp category_label(%{segment: %{name: name}}), do: name
end
