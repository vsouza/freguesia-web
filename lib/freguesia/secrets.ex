defmodule Freguesia.Secrets do
  @moduledoc """
  Chaves derivadas do `secret_key_base` para HMACs internos (códigos, hash de IP).
  Cada uso tem o próprio `purpose`, então uma chave vazada de um uso não serve nos outros.
  """

  @doc "Chave de 32 bytes para `purpose`."
  def derive(purpose) when is_binary(purpose) do
    :crypto.mac(:hmac, :sha256, base_secret(), purpose)
  end

  defp base_secret do
    :freguesia
    |> Application.fetch_env!(FreguesiaWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
