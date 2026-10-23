defmodule FreguesiaWeb.DeviceSession do
  @moduledoc """
  Device identity, without an account (PRD §5 and §13).

    * `device_id`: random UUID in a signed cookie, `HttpOnly`, `SameSite=Lax`.
      Not a fingerprint: it is just a random number.
    * `ip24`: hash of the IP /24 for anti-fraud. Goes into the session, never in the clear.
    * `rate_ip`: HMAC of the IP (IPv4) or its /64 (IPv6) for `Freguesia.RateLimit`.

  They are kept in the session (and `device_id` in `conn.assigns`), so the LiveView can
  read them on mount.
  """
  import Plug.Conn

  alias Freguesia.RateLimit
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

  @doc """
  Client keys for `Freguesia.RateLimit`, read from the session map (a LiveView's mount
  session, or `get_session/1` on a conn).
  """
  def rate_limit_keys(session) when is_map(session) do
    [device: session["device_id"], ip: session["rate_ip"]]
  end

  defp assign_device(conn, device_id) do
    ip = client_ip(conn)

    conn
    |> assign(:device_id, device_id)
    |> put_session("device_id", device_id)
    |> put_session("ip24", Antifraud.ip24_hash_from_text(ip))
    |> put_session("rate_ip", RateLimit.ip_key(ip))
  end

  # Behind the Fly proxy (production), the real IP arrives in `fly-client-ip`. Anywhere
  # else the client could send that header itself, so it is read only when configured.
  defp client_ip(conn) do
    with header when is_binary(header) <- Application.get_env(:freguesia, :client_ip_header),
         [ip | _] <- get_req_header(conn, header) do
      ip
    else
      _ -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
