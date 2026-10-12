defmodule FreguesiaWeb.PageController do
  use FreguesiaWeb, :controller

  # The root (`/`) becomes the onboarding screen in phase 1. For now it falls back to the default neighborhood.
  def home(conn, _params) do
    redirect(conn, to: ~p"/bairro/savassi")
  end
end
