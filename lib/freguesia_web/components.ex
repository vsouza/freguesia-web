defmodule FreguesiaWeb.Components do
  @moduledoc """
  Componentes do design da Freguesia (PRD §12). Ficam separados de `CoreComponents`,
  que são o básico do Phoenix (formulários, botões, tabelas).
  """
  use Phoenix.Component
  use FreguesiaWeb, :verified_routes

  import FreguesiaWeb.CoreComponents, only: [icon: 1]

  alias Freguesia.Catalog.ColorMap

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
    assigns = assign(assigns, verified?: verified?, colors: colors, offer: offer)

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

      <.offer_tag :if={@offer && @offer.tag} text={@offer.tag} />
    </.link>
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

  defp category_colors(%{category: %{color_key: key}}) when is_binary(key),
    do: ColorMap.for_key(key)

  defp category_colors(%{segment: %{color_key: key}}), do: ColorMap.for_key(key)
  defp category_colors(_place), do: ColorMap.neutral()

  defp category_label(%{category: %{name: name}}) when is_binary(name), do: name
  defp category_label(%{segment: %{name: name}}), do: name
end
