defmodule FreguesiaWeb.PromotionController do
  @moduledoc "Promotions tab (PRD §5): approved promotions from verified places, running now."
  use FreguesiaWeb, :controller

  alias Freguesia.Catalog

  def index(conn, _params) do
    render(conn, :index,
      promotions: Catalog.list_active_promotions(),
      page_title: gettext("Promotions"),
      current_neighborhood: current_neighborhood(conn)
    )
  end

  defp current_neighborhood(conn), do: get_session(conn, "neighborhood") || "savassi"
end
