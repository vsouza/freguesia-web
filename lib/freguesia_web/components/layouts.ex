defmodule FreguesiaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FreguesiaWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the consumer layout (catálogo, detalhes, cadastro).

  Mobile-first, coluna central. Inclui o rodapé fixo da regra 7 do PRD (§4)
  em toda tela pública.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-dvh flex-col bg-white">
      <main class="mx-auto flex w-full max-w-md flex-1 flex-col px-4 pb-10 pt-6 md:max-w-3xl">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-line px-4 py-6 text-center text-xs leading-relaxed text-muted">
        A Freguesia é um catálogo: não vendemos, não cobramos e não entregamos pedidos.
        Preço, pagamento e entrega são combinados direto com o estabelecimento.
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the backoffice layout (`/admin`). Utilitário, sem o rodapé de catálogo.

  `operator` é o operador logado, ou `nil` na tela de login.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :operator, :any, default: nil, doc: "the signed-in operator, when there is one"

  slot :inner_block, required: true

  def admin(assigns) do
    ~H"""
    <div class="min-h-dvh bg-sand">
      <header class="border-b border-line bg-white">
        <div class="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <div class="flex items-center gap-6">
            <span class="text-base font-extrabold tracking-tight">
              Freguesia <span class="font-normal text-muted">· backoffice</span>
            </span>
            <nav :if={@operator} aria-label="Backoffice" class="flex gap-1 text-sm font-semibold">
              <.link
                navigate={~p"/admin/verificacoes"}
                class="rounded-full px-3 py-1.5 text-ink-2 hover:bg-sand"
              >
                Verificações
              </.link>
            </nav>
          </div>

          <div :if={@operator} class="flex items-center gap-3 text-sm">
            <span class="hidden text-muted sm:inline">{@operator.email}</span>
            <.link
              href={~p"/admin/sair"}
              method="delete"
              id="admin-logout"
              class="rounded-full border border-line bg-white px-3 py-1.5 font-semibold hover:bg-sand"
            >
              Sair
            </.link>
          </div>
        </div>
      </header>

      <main class="mx-auto max-w-6xl px-4 py-8">
        {render_slot(@inner_block)}
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
