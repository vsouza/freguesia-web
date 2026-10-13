defmodule FreguesiaWeb.PageHTML do
  @moduledoc "Welcome screen (`/`), shown once per device (PRD §5)."
  use FreguesiaWeb, :html

  embed_templates "page_html/*"
end
