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
  Renders the consumer layout (catalog, details, signup).

  Mobile-first, single centered column. Includes the fixed footer from rule 7 of the PRD (§4)
  on every public screen.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_neighborhood, :string,
    default: "savassi",
    doc: "the neighborhood the Home tab points to"

  attr :active_tab, :atom,
    default: nil,
    values: [nil, :home, :search],
    doc: "the active bottom-nav tab"

  attr :wide, :boolean, default: false, doc: "use the wider desktop grid for list screens"

  attr :gradient, :string, default: nil, doc: "category gradient classes for the top band"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-dvh flex-col bg-white">
      <div
        :if={@gradient}
        class={[
          "pointer-events-none absolute inset-x-0 top-0 -z-10 h-72 bg-linear-to-b",
          @gradient,
          "to-white"
        ]}
        aria-hidden="true"
      >
      </div>

      <main class={[
        "mx-auto flex w-full max-w-md flex-1 flex-col px-4 pb-28 pt-6 md:max-w-3xl",
        @wide && "md:max-w-5xl"
      ]}>
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-line px-4 py-6 text-center text-xs leading-relaxed text-muted">
        <nav aria-label={gettext("Legal")} class="mb-3 flex justify-center gap-4 font-bold">
          <.link navigate={~p"/terms"}>Termos</.link>
          <.link navigate={~p"/privacy"}>Privacidade</.link>
          <.link navigate={~p"/how-we-calculate"}>Como calculamos</.link>
        </nav>
        {gettext(
          "Freguesia is a catalog: we don't sell, don't charge and don't deliver orders. Price, payment and delivery are arranged directly with the business."
        )}
      </footer>

      <nav
        aria-label={gettext("Main")}
        class="fixed inset-x-4 bottom-4 z-40 mx-auto flex max-w-sm justify-around rounded-full bg-white px-3 py-2 shadow-nav md:max-w-md"
      >
        <.tab_link
          href={~p"/areas/#{@current_neighborhood}"}
          label={gettext("Home")}
          icon="hero-home"
          active={@active_tab == :home}
        />
        <.tab_link
          href={~p"/search"}
          label={gettext("Search")}
          icon="hero-magnifying-glass"
          active={@active_tab == :search}
        />
      </nav>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false

  defp tab_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      aria-current={@active && "page"}
      class={[
        "flex min-h-11 flex-col items-center justify-center gap-0.5 rounded-full px-5 text-xs font-bold",
        @active && "bg-ink text-white",
        !@active && "text-ink-2 hover:bg-sand"
      ]}
    >
      <.icon name={@icon} class="size-5" />
      {@label}
    </.link>
    """
  end

  @doc """
  Renders the backoffice layout (`/admin`). Utility layout, without the catalog footer.

  `operator` is the logged-in operator, or `nil` on the login screen.
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
              Freguesia <span class="font-normal text-muted">· {gettext("backoffice")}</span>
            </span>
            <nav :if={@operator} aria-label="Backoffice" class="flex gap-1 text-sm font-semibold">
              <.link
                navigate={~p"/admin/places"}
                class="rounded-full px-3 py-1.5 text-ink-2 hover:bg-sand"
              >
                {gettext("Places")}
              </.link>
              <.link
                navigate={~p"/admin/complaints"}
                class="rounded-full px-3 py-1.5 text-ink-2 hover:bg-sand"
              >
                {gettext("Complaints")}
              </.link>
              <.link
                navigate={~p"/admin/verifications"}
                class="rounded-full px-3 py-1.5 text-ink-2 hover:bg-sand"
              >
                {gettext("Verifications")}
              </.link>
            </nav>
          </div>

          <div :if={@operator} class="flex items-center gap-3 text-sm">
            <span class="hidden text-muted sm:inline">{@operator.email}</span>
            <.link
              href={~p"/admin/sign-out"}
              method="delete"
              id="admin-logout"
              class="rounded-full border border-line bg-white px-3 py-1.5 font-semibold hover:bg-sand"
            >
              {gettext("Log out")}
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
