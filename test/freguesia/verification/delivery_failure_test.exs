defmodule Freguesia.Verification.DeliveryFailureTest do
  # async: false on purpose. It swaps the global message adapter; in an async module
  # this would leak into other tests, which would then lose their codes.
  use Freguesia.DataCase, async: false

  alias Freguesia.{Fixtures, Verification}

  defmodule FailingMessaging do
    @behaviour Freguesia.Messaging
    def deliver(_to, _template, _params), do: {:error, :down}
  end

  setup do
    previous = Application.get_env(:freguesia, :messaging)
    Application.put_env(:freguesia, :messaging, FailingMessaging)
    on_exit(fn -> Application.put_env(:freguesia, :messaging, previous) end)
    :ok
  end

  test "failed delivery leaves the place pending and returns :failed" do
    assert {:ok, place, :failed} = Verification.submit_signup(Fixtures.signup_params())
    assert place.status == :pending
  end
end
