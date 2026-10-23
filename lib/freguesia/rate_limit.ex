defmodule Freguesia.RateLimit do
  @moduledoc """
  Rate limits per client (PRD §13), on Hammer's ETS backend with a sliding window, so a
  burst cannot straddle a window boundary.

  `check/2` takes the client's keys (device, IP, operator) and denies when any of them has
  reached the action's limit. A denied request counts on no key, so a client blocked by one
  key does not use up its quota on the others.

  Counters live in the node's memory: they reset on every deploy, and while a deploy runs
  two machines (PRD §15) a client can get up to twice the limit.

  Turned off in the test environment, where every request comes from the same IP; the
  rate limit tests turn it on.
  """
  use Hammer, backend: :ets, algorithm: :sliding_window

  alias Freguesia.Secrets

  @limits %{
    # PRD §13: verification code, 3 every 10 minutes per IP and per device.
    verification_code: {3, :timer.minutes(10)},
    admin_password: {5, :timer.minutes(15)},
    admin_totp: {5, :timer.minutes(15)}
  }

  @type action :: :verification_code | :admin_password | :admin_totp
  @type key :: {atom(), term()}

  @doc """
  Checks `action` for every key and, when all are under the limit, counts one hit on each.
  Returns `:ok`, or `{:error, :rate_limited}` without counting. Keys with a `nil` value
  are ignored.
  """
  @spec check(action(), [key()]) :: :ok | {:error, :rate_limited}
  def check(action, keys) do
    {limit, scale} = Map.fetch!(@limits, action)
    counters = for {_kind, value} = key <- keys, not is_nil(value), do: {action, key}

    cond do
      not enabled?() ->
        :ok

      Enum.any?(counters, &(get(&1, scale) >= limit)) ->
        {:error, :rate_limited}

      true ->
        Enum.each(counters, &hit(&1, scale, limit))
        :ok
    end
  end

  @doc "Window of `action` in minutes, for the message shown to the client."
  @spec window_minutes(action()) :: pos_integer()
  def window_minutes(action) do
    {_limit, scale} = Map.fetch!(@limits, action)
    div(scale, :timer.minutes(1))
  end

  @doc """
  Key for the client's IP: the whole IPv4 address, or the /64 prefix of an IPv6 one (a /64
  usually belongs to one subscriber). An HMAC, so the IP itself never reaches the session.
  `nil` when the text is not an IP.
  """
  @spec ip_key(String.t() | nil) :: binary() | nil
  def ip_key(ip_text) when is_binary(ip_text) do
    case :inet.parse_address(String.to_charlist(ip_text)) do
      {:ok, address} -> address |> unmap_ipv4() |> ip_prefix() |> hash_ip()
      {:error, _reason} -> nil
    end
  end

  def ip_key(_ip_text), do: nil

  @doc "Clears every counter. For tests."
  def reset, do: :ets.delete_all_objects(__MODULE__)

  # An IPv4 client on an IPv6 socket arrives as ::ffff:a.b.c.d.
  defp unmap_ipv4({0, 0, 0, 0, 0, 0xFFFF, _, _} = address),
    do: :inet.ipv4_mapped_ipv6_address(address)

  defp unmap_ipv4(address), do: address

  defp ip_prefix({_, _, _, _} = ipv4), do: ipv4
  defp ip_prefix({a, b, c, d, _, _, _, _}), do: {a, b, c, d, 0, 0, 0, 0}

  defp hash_ip(address) do
    :crypto.mac(:hmac, :sha256, Secrets.derive("rate_limit_ip"), :inet.ntoa(address))
  end

  defp enabled? do
    :freguesia
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:enabled, true)
  end
end
