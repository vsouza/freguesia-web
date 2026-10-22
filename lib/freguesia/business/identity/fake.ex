defmodule Freguesia.Business.Identity.Fake do
  @moduledoc """
  Dev and test identity. The "token" is `fake:<email>`, so the sign-in page can be used
  without a Firebase project. Never configured in production.
  """

  @behaviour Freguesia.Business.Identity

  @impl true
  def verify("fake:" <> email) when email != "" do
    {:ok, %{uid: "fake-" <> email, email: email, name: nil, picture: nil, provider: :password}}
  end

  def verify(_), do: {:error, :invalid_fake_token}
end
