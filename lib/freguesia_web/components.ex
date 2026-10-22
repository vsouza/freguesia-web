defmodule FreguesiaWeb.Components do
  @moduledoc """
  Freguesia design components (PRD §12). Kept separate from `CoreComponents`,
  which are the Phoenix basics (forms, buttons, tables).
  """
  use Phoenix.Component
  use Gettext, backend: FreguesiaWeb.Gettext
  use FreguesiaWeb, :verified_routes
  use Gettext, backend: FreguesiaWeb.Gettext

  import FreguesiaWeb.CoreComponents, only: [icon: 1]

  alias Freguesia.Catalog.ColorMap
  alias Freguesia.Reports.{Savings, Stats}

  attr :place, :any, required: true
  attr :class, :any, default: nil

  @doc """
  Card of a place, following the design mock (PRD §5 and §12a).

  Four states, decided by the place data:
    * verified with an offer and savings: photo, badge, savings chip and tilted offer tag
    * verified with fewer than 10 reports: neutral "Few reports" chip, no average
    * unverified: neutral background, no photo, no offer, Pix warning and outline button
    * closed: grey dot and the opening time; everything else stays the same
  """
  def place_card(assigns) do
    place = assigns.place
    verified? = place.status == :verified
    colors = if verified?, do: category_colors(place), else: ColorMap.neutral()
    # Rule 4 (PRD §4): the card only shows the offer summary; without one, nothing is shown.
    offer = if verified?, do: Freguesia.Catalog.active_offer(place)
    [first | rest] = name_parts(place.name)

    assigns =
      assign(assigns,
        verified?: verified?,
        colors: colors,
        offer: offer,
        name_first: first,
        name_rest: List.first(rest),
        open?: match?({:open, _}, place.hours_status),
        funcionou_text: funcionou_chip(place),
        savings: savings_info(place),
        category: category_label(place)
      )

    ~H"""
    <.link
      navigate={~p"/places/#{@place.slug}"}
      id={"place-card-#{@place.slug}"}
      class={[
        "group relative flex gap-4 overflow-hidden rounded-card p-5 shadow-card transition duration-150 hover:-translate-y-0.5 focus-visible:outline-2 focus-visible:outline-ink",
        @colors.tint,
        @class
      ]}
    >
      <.offer_tag :if={@offer && @offer.tag} text={@offer.tag} class="absolute right-4 top-4" />

      <div class="flex min-w-0 flex-1 flex-col gap-2.5">
        <div class="pr-20 leading-none">
          <p :if={@name_rest} class="text-xl font-light italic text-ink-2">{@name_first}</p>
          <h3 class="text-xl font-extrabold text-ink">{@name_rest || @name_first}</h3>
        </div>

        <div class="flex flex-wrap items-center gap-2 text-xs">
          <span class={[
            "rounded-full bg-white px-2.5 py-1 font-bold uppercase tracking-wide",
            @colors.accent
          ]}>
            {@category}
          </span>
          <span class="text-muted">{@place.neighborhood.name}</span>
        </div>

        <p class="flex items-center gap-2 text-sm text-ink-2">
          <span
            class={["size-2 flex-none rounded-full", @open? && "bg-tomato-500", !@open? && "bg-muted"]}
            aria-hidden="true"
          >
          </span>
          <FreguesiaWeb.Components.hours_label status={@place.hours_status} />
        </p>

        <div class="flex flex-wrap gap-2">
          <.verified_badge :if={@verified?} />
          <.unverified_chip :if={!@verified?} />
          <.savings_chip
            :if={@verified? and @savings.reliable?}
            percent={@savings.percent}
            count={@savings.count}
          />
          <.proof_chip
            :if={@verified? and !@savings.reliable?}
            text={gettext("Few reports (%{count})", count: @savings.count)}
          />
          <.proof_chip :if={@funcionou_text} text={@funcionou_text} />
        </div>

        <.not_verified_note :if={!@verified?} />

        <span
          :if={@verified?}
          class="mt-1 inline-flex min-h-11 w-fit items-center gap-2 rounded-full bg-ink px-5 text-sm font-bold text-white"
        >
          {gettext("See and order")} <.icon name="hero-arrow-up-right-mini" class="size-4" />
        </span>
        <span
          :if={!@verified?}
          class="mt-1 inline-flex min-h-11 w-fit items-center rounded-full border border-ink px-5 text-sm font-bold text-ink"
        >
          {gettext("Open chat")}
        </span>
      </div>

      <div class="relative aspect-square w-[116px] flex-none self-center overflow-hidden rounded-card md:w-[132px]">
        <img
          :if={@verified? and @place.photo_key}
          src={~p"/photos/#{@place.photo_key}"}
          alt=""
          loading="lazy"
          class="size-full object-cover"
        />
        <div
          :if={!(@verified? and @place.photo_key)}
          class="flex size-full flex-col items-center justify-center gap-1 bg-white/60 p-2 text-center text-[11px] text-muted"
        >
          <.icon name="hero-photo" class="size-6" />
          <span>
            {if @verified?, do: gettext("No photo yet"), else: gettext("No photo until verified")}
          </span>
        </div>
      </div>
    </.link>
    """
  end

  defp name_parts(name) do
    case String.split(name, " ", parts: 2) do
      [single] -> [single]
      [first, rest] -> [first, rest]
    end
  end

  defp unverified_chip(assigns) do
    ~H"""
    <span class="inline-flex items-center rounded-full bg-white px-3 py-1 text-xs font-bold uppercase tracking-wide text-cat-grape-accent">
      {gettext("Not verified")}
    </span>
    """
  end

  attr :percent, :any, required: true
  attr :count, :integer, required: true

  defp savings_chip(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 rounded-full bg-ink px-3 py-1 text-xs font-bold text-white">
      <span class="text-gold">{round_percent(@percent)}%</span>
      {gettext("less · %{count} reports", count: @count)}
    </span>
    """
  end

  # Without loaded stats (previews, pages that do not preload them) there is nothing to prove.
  defp savings_info(%{stats: stats} = place) when is_list(stats) do
    stat = Stats.window(place, "90d")
    count = stat.savings_hist |> Map.values() |> Enum.sum()

    %{reliable?: count >= 10, count: count, percent: stat.savings_avg, loaded?: true}
  end

  defp savings_info(_place), do: %{reliable?: false, count: 0, percent: nil, loaded?: false}

  defp round_percent(nil), do: 0
  defp round_percent(avg), do: avg |> Decimal.round(0) |> Decimal.to_integer()

  @doc """
  Proof that ordering directly works: "Funcionou 31/33". Only shows with at least
  1 answer in 30 days (PRD §8).
  """
  attr :text, :string, required: true

  def proof_chip(assigns) do
    ~H"""
    <span class="rounded-full bg-white/70 px-2.5 py-1 text-xs font-bold text-ink-2">{@text}</span>
    """
  end

  @doc "Verified badge. The only element in indigo (PRD §12)."
  def verified_badge(assigns) do
    ~H"""
    <span class="inline-flex flex-none items-center gap-1 rounded-full bg-indigo-100 px-2.5 py-1 text-xs font-bold text-indigo-800">
      <.icon name="hero-check-badge-mini" class="size-4" /> {gettext("Verified")}
    </span>
    """
  end

  @doc """
  Slanted tag with the offer summary (rule 4: only the summary on the card).
  """
  attr :text, :string, required: true
  attr :class, :any, default: nil

  def offer_tag(assigns) do
    ~H"""
    <span class={[
      "inline-flex w-fit -rotate-2 items-center gap-1.5 rounded-tile bg-ink px-3 py-1.5 text-sm font-bold text-white shadow-tag",
      @class
    ]}>
      <.icon name="hero-tag-mini" class="size-4 text-gold" />
      {@text}
    </span>
    """
  end

  @doc "Opening state: open, closed, paused (PRD §8)."
  attr :status, :any, required: true

  def hours_label(assigns) do
    ~H"""
    <%= case @status do %>
      <% {:open, closes_at} -> %>
        <span class="font-bold text-ink">{gettext("Open")}</span>
        <span class="ml-1 text-ink-2">{gettext("· until %{time}", time: closes_at)}</span>
      <% {:closed, nil} -> %>
        <span class="font-bold text-muted">{gettext("Closed")}</span>
      <% {:closed, opens_at} -> %>
        <span class="font-bold text-muted">{gettext("Closed")}</span>
        <span class="ml-1 text-muted">{gettext("· opens at %{time}", time: opens_at)}</span>
      <% {:paused} -> %>
        <span class="font-bold text-muted">{gettext("Not taking orders today")}</span>
    <% end %>
    """
  end

  defp not_verified_note(assigns) do
    ~H"""
    <p class="text-xs text-muted">{gettext("Not verified by the restaurant yet.")}</p>
    """
  end

  @doc """
  Bottom sheet (WhatsApp return, PRD §5). No dark backdrop: focus stays on it.
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
  Histogram of the five savings bands (PRD §8). The average band is highlighted.
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
      aria-label={
        gettext("Reported savings distribution. Average band: %{band}.",
          band: Savings.label(@highlight)
        )
      }
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
  "Funcionou X/Y em 30 dias". Bar only shows with 5 or more answers (PRD §8).
  """
  attr :worked, :integer, required: true
  attr :responses, :integer, required: true

  def funcionou_bar(assigns) do
    ~H"""
    <div>
      <p class="text-sm font-bold text-ink">
        <%= if @responses == 0 do %>
          {gettext("No answers in the last 30 days yet")}
        <% else %>
          {gettext("Worked %{worked}/%{responses} in 30 days", worked: @worked, responses: @responses)}
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

  @doc "Warning in an attention box (saffron color)."
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

  @doc "Empty state with an optional action."
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

  @doc "Two-part title (PRD §12): line 1 italic 300, line 2 bold 800."
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
  QR code in SVG. The SVG comes from `EQRCode` based on the TOTP URI, never from user input,
  so it is safe to insert it without escaping.
  """
  attr :svg, :string, required: true

  # sobelow_skip ["XSS.Raw"]
  def qr_code(assigns) do
    ~H"""
    {Phoenix.HTML.raw(@svg)}
    """
  end

  @doc """
  WhatsApp link with the default message (PRD §11). The number comes in E.164
  and `wa.me` only takes the digits.
  """
  def whatsapp_url(place_name, whatsapp_e164) do
    digits = String.trim_leading(whatsapp_e164, "+")
    text = gettext("Hi! I saw %{name} on Freguesia and want to order direct.", name: place_name)
    "https://wa.me/#{digits}?text=#{URI.encode(text, &URI.char_unreserved?/1)}"
  end

  defp funcionou_chip(place) do
    if is_list(place.stats) do
      stat = Stats.window(place, "30d")

      if stat.responses >= 1,
        do:
          gettext("Worked %{worked}/%{responses}", worked: stat.worked, responses: stat.responses)
    end
  end

  defp percent(_part, 0), do: 0
  defp percent(part, total), do: round(part * 100 / total)

  defp category_colors(%{category: %{color_key: key}}) when is_binary(key),
    do: ColorMap.for_key(key)

  defp category_colors(%{segment: %{color_key: key}}), do: ColorMap.for_key(key)
  defp category_colors(_place), do: ColorMap.neutral()

  defp category_label(%{category: %{key: key}}) when is_binary(key),
    do: FreguesiaWeb.Labels.category_label(key)

  defp category_label(%{segment: %{key: key}}), do: FreguesiaWeb.Labels.segment_label(key)
end
