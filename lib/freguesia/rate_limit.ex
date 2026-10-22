defmodule Freguesia.RateLimit do
  @moduledoc """
  Rate limits per client (PRD §13), on Hammer's ETS backend.

  `check/2` counts one hit for each key of the client (device, IP /24 hash, email, operator)
  and denies when any of them is over the action's limit. Counters live in each node's
  memory: with two machines a client can get up to twice the limit, which still stops abuse.

  Turned off in the test environment, where every request comes from the same IP; the
  rate limit tests turn it on.
  """
  use Hammer, backend: :ets

  @limits %{
    # PRD §13: verification code, 3 every 10 minutes per IP and per device.
    verification_code: {3, :timer.minutes(10)},
    admin_password: {5, :timer.minutes(15)},
    admin_totp: {5, :timer.minutes(15)}
  }

  @type action :: :verification_code | :admin_password | :admin_totp
  @type key :: {atom(), term()}

  @doc """
  Counts one hit of `action` for every key. Returns `:ok`, or `{:error, :rate_limited}`
  when any key is over the limit. Keys with a `nil` value are ignored.
  """
  @spec check(action(), [key()]) :: :ok | {:error, :rate_limited}
  def check(action, keys) do
    {limit, scale} = Map.fetch!(@limits, action)

    if enabled?() do
      keys
      |> Enum.reject(fn {_kind, value} -> is_nil(value) end)
      |> Enum.map(fn key -> hit({action, key}, scale, limit) end)
      |> Enum.all?(&match?({:allow, _count}, &1))
      |> if(do: :ok, else: {:error, :rate_limited})
    else
      :ok
    end
  end

  defp enabled? do
    :freguesia
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:enabled, true)
  end
end
