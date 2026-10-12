defmodule FreguesiaWeb.PlaceLive do
  @moduledoc """
  Detalhes de um lugar (PRD §5). Nesta fase: foto (placeholder da categoria),
  status, oferta aprovada e o botão para pedir no WhatsApp.

  Ainda sem o registro de abertura, a folha de retorno e os relatos de economia:
  isso é da fase 1.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.Catalog
  alias Freguesia.Catalog.ColorMap

  @visible_statuses [:verified, :paused]

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    place = Catalog.get_place_by_slug(slug)

    if place && place.status in @visible_statuses do
      {:ok,
       socket
       |> assign(
         page_title: place.name,
         place: place,
         offer: Catalog.active_offer(place),
         colors:
           ColorMap.for_key(
             (place.category && place.category.color_key) || place.segment.color_key
           ),
         whatsapp_url: FreguesiaWeb.Components.whatsapp_url(place.name, place.whatsapp_e164)
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "Esse lugar não está no catálogo.")
       |> push_navigate(to: ~p"/bairro/savassi")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
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
          <FreguesiaWeb.Components.verified_badge :if={@place.status == :verified} />
          <span class="text-sm text-ink-2">
            <FreguesiaWeb.Components.hours_label status={@place.hours_status} />
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
          <%= if @place.status == :verified and @place.hours_status != {:paused} do %>
            <a
              href={@whatsapp_url}
              id="whatsapp-cta"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-ink px-6 text-base font-bold text-white transition duration-150 hover:bg-ink-2 active:scale-[0.98]"
            >
              <.icon name="hero-chat-bubble-left-ellipsis" class="size-5" /> Pedir no WhatsApp
            </a>
          <% else %>
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
    </Layouts.app>
    """
  end

  defp delivery_label(:own), do: "Entrega própria"
  defp delivery_label(:partner), do: "Motoboy parceiro"

  defp format_date(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y")
end
