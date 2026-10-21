defmodule Freguesia.Business.Identity.Firebase do
  @moduledoc """
  Verifies a Firebase ID token with the Identity Toolkit `accounts:lookup` endpoint.
  Google checks the token's signature and expiry. We call it once per sign-in; later
  requests use our own session cookie (PRD §6).
  """

  @behaviour Freguesia.Business.Identity

  @lookup_url "https://identitytoolkit.googleapis.com/v1/accounts:lookup"

  @impl true
  def verify(id_token) when is_binary(id_token) and id_token != "" do
    case Req.post(@lookup_url,
           params: [key: api_key()],
           json: %{idToken: id_token},
           receive_timeout: 5_000
         ) do
      {:ok, %{status: 200, body: %{"users" => [user | _]}}} -> {:ok, claims(user)}
      {:ok, %{status: status}} -> {:error, {:firebase, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  def verify(_), do: {:error, :missing_token}

  defp api_key do
    Application.fetch_env!(:freguesia, :firebase_api_key) ||
      raise "FIREBASE_API_KEY is not set"
  end

  defp claims(user) do
    %{
      uid: user["localId"],
      email: user["email"],
      name: user["displayName"],
      picture: user["photoUrl"],
      provider: provider(user["providerUserInfo"])
    }
  end

  defp provider([%{"providerId" => "google.com"} | _]), do: :google
  defp provider([%{"providerId" => "apple.com"} | _]), do: :apple
  defp provider(_), do: :password
end
