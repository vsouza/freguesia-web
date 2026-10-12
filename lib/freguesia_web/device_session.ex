defmodule FreguesiaWeb.DeviceSession do
  @moduledoc """
  Identidade do dispositivo, sem conta (PRD §5 e §13).

    * `device_id`: UUID aleatório em cookie assinado, `HttpOnly`, `SameSite=Lax`.
      Não é fingerprint: é só um número sorteado.
    * `ip24`: hash do /24 do IP para o antifraude. Vai para a sessão, nunca em claro.

  Os dois ficam em `conn.assigns` e na sessão, para o LiveView ler no mount.
  """
  import Plug.Conn

  alias Freguesia.Reports.Antifraud

  @cookie "device_id"
  @max_age 2 * 365 * 24 * 60 * 60

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn, signed: [@cookie])

    case conn.cookies[@cookie] do
      nil ->
        device_id = UUIDv7.generate()

        conn
        |> put_resp_cookie(@cookie, device_id,
          sign: true,
          http_only: true,
          same_site: "Lax",
          max_age: @max_age
        )
        |> assign_device(device_id)

      device_id ->
        assign_device(conn, device_id)
    end
  end

  defp assign_device(conn, device_id) do
    ip24 = Antifraud.ip24_hash_from_text(client_ip(conn))

    conn
    |> assign(:device_id, device_id)
    |> put_session("device_id", device_id)
    |> put_session("ip24", ip24)
  end

  # Atrás do proxy do Fly, o IP real vem em `fly-client-ip`.
  defp client_ip(conn) do
    case get_req_header(conn, "fly-client-ip") do
      [ip | _] -> ip
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
