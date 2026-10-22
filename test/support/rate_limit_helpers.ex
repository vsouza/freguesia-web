defmodule Freguesia.RateLimitHelpers do
  @moduledoc """
  Turns `Freguesia.RateLimit` on for one test, starting from empty counters.

  Only for `async: false` modules: the setting is global, and in an async module it would
  leak into other tests, which all come from 127.0.0.1.
  """
  import ExUnit.Callbacks, only: [on_exit: 1]

  alias Freguesia.RateLimit

  def enable_rate_limit(_context) do
    previous = Application.get_env(:freguesia, RateLimit)
    Application.put_env(:freguesia, RateLimit, enabled: true)
    RateLimit.reset()
    on_exit(fn -> Application.put_env(:freguesia, RateLimit, previous) end)
    :ok
  end
end
