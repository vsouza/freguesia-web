defmodule Freguesia.Verification.DeliveryFailureTest do
  # async: false de propósito. Troca o adaptador global de mensagens; em módulo
  # assíncrono isso vazaria para os outros testes e eles perderiam o código.
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

  test "envio falho deixa o lugar pending e devolve :failed" do
    assert {:ok, place, :failed} = Verification.submit_signup(Fixtures.signup_params())
    assert place.status == :pending
  end
end
