defmodule FreguesiaWeb.PhotoController do
  @moduledoc """
  `GET /photos/:key`: serves a stored place photo (PRD §10). Keys are random UUIDs,
  so the response can be cached for a year.

  `Photos.path/1` accepts only a UUID with a known extension, so nothing outside the
  photo directory can be read. Photos are at most 5 MB, so they are read and sent
  in one piece.
  """
  use FreguesiaWeb, :controller

  alias Freguesia.Photos

  def show(conn, %{"key" => key}) do
    case Photos.read(key) do
      {:ok, bytes} ->
        conn
        |> put_resp_header("content-type", Photos.content_type(key))
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_resp(200, bytes)

      :error ->
        send_resp(conn, 404, "")
    end
  end
end
