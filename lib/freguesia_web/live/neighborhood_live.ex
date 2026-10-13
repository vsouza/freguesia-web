defmodule FreguesiaWeb.NeighborhoodLive do
  @moduledoc """
  Home of a pilot neighborhood (`/areas/:neighborhood`, PRD §5).

  Segment and food-type chips, filters (open now, with perk, verified), name
  search and the place list. The filters live in the URL, so the page can be
  shared and reloaded.
  """
  use FreguesiaWeb, :live_view

  alias Freguesia.{Catalog, Events}
  alias Freguesia.Catalog.ColorMap
  alias FreguesiaWeb.Labels

  @impl true
  def mount(%{"neighborhood" => slug}, session, socket) do
    case Catalog.get_pilot_neighborhood_by_slug(slug) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/areas/savassi")}

      neighborhood ->
        if connected?(socket) do
          Events.track("home_viewed", %{neighborhood: slug}, session["device_id"])
        end

        {:ok,
         socket
         |> assign(
           page_title: neighborhood.name,
           neighborhood: neighborhood,
           device_id: session["device_id"],
           segments: Labels.segment_order(),
           categories: restaurant_categories(),
           all_places: Catalog.list_home_places(neighborhood)
         )}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = parse_filters(params)
    now = DateTime.utc_now()
    places = Catalog.list_home_places(socket.assigns.neighborhood, now, filters)

    track_filter_events(filters, socket)

    {:noreply,
     socket
     |> assign(
       filters: filters,
       filters_active?: filters_active?(filters),
       coming_soon?: coming_soon?(socket.assigns.all_places, filters),
       places_count: length(places),
       gradient: segment_gradient(filters.segment)
     )
     |> stream(:places, places, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_neighborhood={@neighborhood.slug}
      active_tab={:home}
      gradient={@gradient}
      wide={true}
    >
      <header class="flex flex-col gap-1 pb-4">
        <p class="text-xs font-bold uppercase tracking-wide text-muted">{gettext("Neighborhood")}</p>
        <h1 class="text-3xl font-extrabold tracking-tight text-ink">{@neighborhood.name}</h1>
        <p class="text-sm text-muted">
          {gettext("Verified places, confirmed by the business itself.")}
        </p>
      </header>

      <form
        id="home-search"
        method="get"
        action={~p"/areas/#{@neighborhood.slug}"}
        class="flex flex-col gap-3"
      >
        <.hidden_filters filters={@filters} />
        <label for="home-search-input" class="sr-only">{gettext("Search by name")}</label>
        <input
          id="home-search-input"
          type="search"
          name="q"
          value={@filters.query}
          placeholder={gettext("Search by name")}
          class="block h-12 w-full rounded-full border border-line bg-white px-5 text-base text-ink placeholder:text-muted focus:border-ink focus:outline-none focus:ring-2 focus:ring-ink/10"
        />
      </form>

      <nav aria-label={gettext("Segments")} class="-mx-4 mt-4 flex gap-2 overflow-x-auto px-4 pb-1">
        <.chip
          :for={segment <- ["all" | @segments]}
          id={"segment-#{segment}"}
          patch={filter_url(@neighborhood, @filters, %{segment: segment, category: nil})}
          active={@filters.segment == segment or (segment == "all" and @filters.segment == "all")}
          label={Labels.segment_label(segment)}
        />
      </nav>

      <nav
        :if={@filters.segment == "restaurants"}
        aria-label={gettext("Food type")}
        class="-mx-4 mt-2 flex gap-2 overflow-x-auto px-4 pb-1"
      >
        <.chip
          :for={category <- @categories}
          id={"category-#{category.key}"}
          patch={filter_url(@neighborhood, @filters, %{category: category.key})}
          active={@filters.category == category.key}
          label={Labels.category_label(category.key)}
        />
      </nav>

      <div class="mt-3 flex flex-wrap gap-2">
        <.chip
          id="filter-open"
          patch={filter_url(@neighborhood, @filters, %{open: !@filters.open})}
          active={@filters.open}
          label={gettext("Open now")}
        />
        <.chip
          id="filter-perk"
          patch={filter_url(@neighborhood, @filters, %{perk: !@filters.perk})}
          active={@filters.perk}
          label={gettext("With a perk")}
        />
        <.chip
          id="filter-verified"
          patch={filter_url(@neighborhood, @filters, %{verified: !@filters.verified})}
          active={@filters.verified}
          label={gettext("Verified")}
        />
      </div>

      <div id="places" phx-update="stream" class="mt-6 flex flex-col gap-4 md:grid md:grid-cols-3">
        <div :for={{dom_id, place} <- @streams.places} id={dom_id}>
          <FreguesiaWeb.Components.place_card place={place} />
        </div>
      </div>

      <div :if={@places_count == 0 and @coming_soon?} id="coming-soon">
        <FreguesiaWeb.Components.empty_state title={gettext("Coming soon")}>
          {gettext("No places in this segment yet. Know one that should be here?")}
        </FreguesiaWeb.Components.empty_state>
        <.link
          navigate={~p"/business/register"}
          class="mt-3 inline-flex text-sm font-bold text-ink underline underline-offset-4"
        >
          {gettext("Suggest a place")}
        </.link>
      </div>

      <div :if={@places_count == 0 and not @coming_soon? and @filters_active?} id="nothing-found">
        <FreguesiaWeb.Components.empty_state title={gettext("Nothing found")}>
          {gettext("Try another search or remove some filters.")}
        </FreguesiaWeb.Components.empty_state>
        <.link
          patch={~p"/areas/#{@neighborhood.slug}"}
          class="mt-3 inline-flex text-sm font-bold text-ink underline underline-offset-4"
        >
          {gettext("Clear filters")}
        </.link>
      </div>

      <section id="for-businesses" class="mt-10 rounded-card bg-sand p-5">
        <p class="font-bold text-ink">{gettext("Do you serve this neighborhood?")}</p>
        <p class="mt-1 text-sm text-ink-2">
          {gettext("Get verified in a few minutes and let regulars order from you directly.")}
        </p>
        <.link
          navigate={~p"/business/register"}
          class="mt-3 inline-flex text-sm font-bold text-ink underline underline-offset-4"
        >
          {gettext("Get verified")}
        </.link>
      </section>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :patch, :string, required: true

  defp chip(assigns) do
    ~H"""
    <.link
      id={@id}
      patch={@patch}
      aria-pressed={to_string(@active)}
      class={[
        "inline-flex min-h-11 flex-none items-center rounded-full border px-4 text-sm font-bold transition",
        @active && "border-ink bg-ink text-white",
        !@active && "border-line bg-white text-ink-2 hover:bg-sand"
      ]}
    >
      {@label}
    </.link>
    """
  end

  attr :filters, :map, required: true

  defp hidden_filters(assigns) do
    ~H"""
    <input :if={@filters.segment != "all"} type="hidden" name="segment" value={@filters.segment} />
    <input :if={@filters.category} type="hidden" name="category" value={@filters.category} />
    <input :if={@filters.open} type="hidden" name="open" value="1" />
    <input :if={@filters.perk} type="hidden" name="perk" value="1" />
    <input :if={@filters.verified} type="hidden" name="verified" value="1" />
    """
  end

  defp parse_filters(params) do
    %{
      segment: params["segment"] || "all",
      category: blank_to_nil(params["category"]),
      open: params["open"] == "1",
      perk: params["perk"] == "1",
      verified: params["verified"] == "1",
      query: blank_to_nil(params["q"])
    }
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp filters_active?(filters) do
    filters.segment != "all" or filters.category != nil or filters.open or filters.perk or
      filters.verified or filters.query != nil
  end

  # "Coming soon" when nothing in this neighborhood matches the chosen segment (or
  # the neighborhood has no places at all for "All"), and no other filter is applied.
  defp coming_soon?(all_places, %{segment: segment} = filters) do
    has_match? =
      Enum.any?(all_places, fn place -> segment == "all" or place.segment.key == segment end)

    not filters_active?(%{filters | segment: "all"}) and not has_match?
  end

  defp track_filter_events(filters, socket) do
    device_id = socket.assigns.device_id

    if filters.category do
      Events.track("category_selected", %{category: filters.category}, device_id)
    end

    if filters.query do
      Events.track("search_performed", %{screen: "home"}, device_id)
    end
  end

  defp restaurant_categories do
    case Catalog.get_segment_by_key("restaurants") do
      nil ->
        []

      segment ->
        Freguesia.Repo.preload(segment, :categories).categories |> Enum.sort_by(& &1.name)
    end
  end

  defp segment_gradient(segment) do
    key = if segment in [nil, "all"], do: "peach", else: segment_color_key(segment)
    ColorMap.for_key(key).gradient
  end

  defp segment_color_key("restaurants"), do: "peach"
  defp segment_color_key("pharmacies"), do: "water"
  defp segment_color_key("grocery"), do: "orange"
  defp segment_color_key("hardware"), do: "concrete"
  defp segment_color_key("pet"), do: "pitaya"
  defp segment_color_key(_), do: "peach"

  # Builds a link to this neighborhood's home with the given filter changes applied.
  defp filter_url(neighborhood, filters, changes) do
    params =
      filters
      |> Map.merge(changes)
      |> Enum.reject(fn {_key, value} -> value in [nil, false, "all", ""] end)
      |> Map.new(fn
        {key, true} -> {Atom.to_string(key), "1"}
        {key, value} -> {Atom.to_string(key), value}
      end)
      |> rename_query_key()

    base = "/areas/#{neighborhood.slug}"
    if params == %{}, do: base, else: base <> "?" <> URI.encode_query(params)
  end

  defp rename_query_key(params) do
    case Map.pop(params, "query") do
      {nil, rest} -> rest
      {value, rest} -> Map.put(rest, "q", value)
    end
  end
end
