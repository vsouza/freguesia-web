defmodule FreguesiaWeb.WhatsAppController do
  @moduledoc """
  `GET /r/:slug`: records the opening and sends the customer to the place's WhatsApp.

  The record is written before the redirect, so it works without JavaScript.
  When the button is hidden (complaints) or the place is paused, there is no opening:
  the customer goes back to the place page with the explanation.
  """
  use FreguesiaWeb, :controller

  alias Freguesia.{Catalog, Events, Reports}
  alias FreguesiaWeb.Components

  def open(conn, %{"slug" => slug}) do
    device_id = conn.assigns.device_id
    place = Catalog.get_place_by_slug(slug)

    cond do
      is_nil(place) or place.status != :verified ->
        conn
        |> put_flash(:error, "Esse lugar não está no catálogo.")
        |> redirect(to: ~p"/bairro/savassi")

      place.hours_status == {:paused} ->
        conn
        |> put_flash(:error, "Esse lugar não está atendendo hoje.")
        |> redirect(to: ~p"/lugar/#{slug}")

      Reports.whatsapp_hidden?(place.id) ->
        conn
        |> put_flash(:error, "Esse número está em revisão e não aparece para pedido agora.")
        |> redirect(to: ~p"/lugar/#{slug}")

      true ->
        {:ok, _open} = Reports.open_whatsapp(place.id, device_id)
        Events.track("whatsapp_open", %{place_slug: slug}, device_id)

        redirect(conn,
          external: Components.whatsapp_url(place.name, place.whatsapp_e164)
        )
    end
  end
end
