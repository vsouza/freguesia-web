defmodule FreguesiaWeb.Locale do
  @moduledoc """
  Sets the UI locale for the request and for each LiveView process.

  Source strings are written in English. The product ships in Brazilian
  Portuguese (`pt_BR`) through Gettext (PRD §1). Set the locale here so that
  `gettext/1` in templates, flash messages and changeset errors all agree.
  """
  import Plug.Conn

  @default_locale "pt_BR"

  def init(opts), do: opts

  @doc "Plug: sets the locale for the HTTP request."
  def call(conn, _opts) do
    Gettext.put_locale(FreguesiaWeb.Gettext, @default_locale)
    assign(conn, :locale, @default_locale)
  end

  @doc "`on_mount` hook: sets the locale for the LiveView process."
  def on_mount(:default, _params, session, socket) do
    Gettext.put_locale(FreguesiaWeb.Gettext, @default_locale)

    socket =
      socket
      |> Phoenix.Component.assign(:locale, @default_locale)
      |> Phoenix.Component.assign(:current_neighborhood, session["neighborhood"] || "savassi")

    {:cont, socket}
  end
end
