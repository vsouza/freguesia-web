defmodule Freguesia.Verification.Phone do
  @moduledoc """
  Normalizes a Brazilian WhatsApp number to E.164 (`+55DDDNUMBER`).

  Accepts input with or without formatting, with or without `+55`. The DDD 55 ambiguity is resolved
  by length: 12 or 13 digits with `55` in front already include the country code.
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
