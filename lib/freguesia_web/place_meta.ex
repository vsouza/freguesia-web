defmodule FreguesiaWeb.PlaceMeta do
  @moduledoc """
  Open Graph tags for a place page (PRD §5, deep link and sharing).

  Runs before the LiveView renders, so the tags are in the first HTML response
  and link previews work without running JavaScript. The root layout writes them
  from `conn.assigns.og`.
  """
  use Gettext, backend: FreguesiaWeb.Gettext

  import Plug.Conn

  alias Freguesia.Catalog

  def init(opts), do: opts

  def call(%{params: %{"slug" => slug}} = conn, _opts) do
    case Catalog.get_place_by_slug(slug) do
      nil ->
        conn

      place ->
        assign(conn, :og, %{
          "og:type" => "business.business",
          "og:title" => place.name,
          "og:description" =>
            gettext("Verified on Freguesia, in %{neighborhood}. Order direct on WhatsApp.",
              neighborhood: place.neighborhood.name
            ),
          "og:url" => FreguesiaWeb.Endpoint.url() <> "/places/" <> place.slug
        })
    end
  end

  def call(conn, _opts), do: conn
end
