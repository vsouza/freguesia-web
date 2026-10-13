defmodule FreguesiaWeb.LegalController do
  @moduledoc """
  Terms, privacy policy and "How we calculate" (PRD §13). The texts live in the
  repository, versioned by `@version`. They are drafts until the lawyer review
  mentioned in the PRD (§17).
  """
  use FreguesiaWeb, :controller

  @version "2026-10-13"

  def terms(conn, _params),
    do: render(conn, :terms, version: @version, page_title: "Termos de uso")

  def privacy(conn, _params),
    do: render(conn, :privacy, version: @version, page_title: "Privacidade")

  def how_we_calculate(conn, _params),
    do: render(conn, :how_we_calculate, version: @version, page_title: "Como calculamos")
end
