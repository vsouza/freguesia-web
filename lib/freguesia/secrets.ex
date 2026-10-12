defmodule Freguesia.Secrets do
  @moduledoc """
  Keys derived from `secret_key_base` for internal HMACs (codes, IP hash).
  Each use has its own `purpose`, so a key leaked from one use is useless for the others.
  """

  @doc "32-byte key for `purpose`."
  def derive(purpose) when is_binary(purpose) do
    :crypto.mac(:hmac, :sha256, base_secret(), purpose)
  end

  defp base_secret do
    :freguesia
    |> Application.fetch_env!(FreguesiaWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
