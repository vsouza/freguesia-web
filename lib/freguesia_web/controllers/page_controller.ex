defmodule FreguesiaWeb.PageController do
  use FreguesiaWeb, :controller

  # A inicial (`/`) vira a tela de onboarding na fase 1. Por ora, cai no bairro padrão.
  def home(conn, _params) do
    redirect(conn, to: ~p"/bairro/savassi")
  end
end
