defmodule Freguesia.Verification.Phone do
  @moduledoc """
  Normaliza um WhatsApp brasileiro para E.164 (`+55DDDNÚMERO`).

  Aceita com ou sem máscara, com ou sem `+55`. Ambiguidade de DDD 55 resolve-se
  pelo tamanho: 12 ou 13 dígitos com `55` na frente já trazem o país.
  """

  @e164 ~r/^\+55[1-9]\d{9,10}$/

  @spec normalize(String.t()) :: {:ok, String.t()} | :error
  def normalize(input) when is_binary(input) do
    digits = String.replace(input, ~r/\D/, "")

    candidate =
      cond do
        String.starts_with?(digits, "55") and byte_size(digits) in [12, 13] -> "+" <> digits
        byte_size(digits) in [10, 11] -> "+55" <> digits
        true -> nil
      end

    if candidate && Regex.match?(@e164, candidate), do: {:ok, candidate}, else: :error
  end

  def normalize(_), do: :error
end
