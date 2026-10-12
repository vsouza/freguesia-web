defmodule Freguesia.Reports.Antifraud do
  @moduledoc """
  Antifraude dos relatos (PRD §8 e §13).

    * No máximo 3 relatos válidos por dispositivo por lugar em 30 dias. Os excedentes
      ficam `valid = false` com motivo `device_limit`.
    * Lote suspeito: mais de 10 relatos do mesmo /24 em 1 hora. O relato que passa
      do limite fica `valid = false` com motivo `batch_review`, até o operador liberar.

    O /24 nunca é guardado em claro. Guarda-se um HMAC com chave que muda por dia, e o
    hash é apagado depois de 30 dias (ver `Freguesia.Reports.purge_ip_hashes/1`).
  """
  import Ecto.Query, warn: false

  alias Freguesia.Repo
  alias Freguesia.Reports.Report
  alias Freguesia.Secrets

  @device_limit 3
  @device_window_days 30
  @batch_limit 10
  @batch_window_seconds 60 * 60

  @doc """
  Motivo de invalidação para um relato novo, ou `nil` se ele é válido.
  Consulta os relatos já gravados, antes do insert.
  """
  def invalid_reason(device_id, place_id, ip24_hash, now) do
    cond do
      device_limit_reached?(device_id, place_id, now) -> "device_limit"
      batch_suspicious?(ip24_hash, now) -> "batch_review"
      true -> nil
    end
  end

  @doc "Hash do /24 de um IP IPv4 (tupla ou string), com salt diário. `nil` sem IP."
  def ip24_hash(nil), do: nil

  def ip24_hash({a, b, c, _d}), do: ip24_hash("#{a}.#{b}.#{c}")

  def ip24_hash(prefix) when is_binary(prefix) do
    :crypto.mac(:hmac, :sha256, daily_key(Date.utc_today()), prefix)
  end

  @doc "Extrai o /24 de um IP textual (`a.b.c.d`). Fora de IPv4, devolve `nil`."
  def ip24_hash_from_text(text) when is_binary(text) do
    case String.split(text, ".") do
      [a, b, c, _d] -> ip24_hash("#{a}.#{b}.#{c}")
      _ -> nil
    end
  end

  def ip24_hash_from_text(_), do: nil

  defp daily_key(date) do
    Secrets.derive("ip24:" <> Date.to_iso8601(date))
  end

  defp device_limit_reached?(device_id, place_id, now) do
    since = DateTime.add(now, -@device_window_days * 86_400)

    count =
      Repo.aggregate(
        from(r in Report,
          where:
            r.device_id == ^device_id and r.place_id == ^place_id and r.valid == true and
              r.answered_at >= ^since
        ),
        :count
      )

    count >= @device_limit
  end

  defp batch_suspicious?(nil, _now), do: false

  defp batch_suspicious?(ip24_hash, now) do
    since = DateTime.add(now, -@batch_window_seconds)

    count =
      Repo.aggregate(
        from(r in Report, where: r.ip24_hash == ^ip24_hash and r.answered_at >= ^since),
        :count
      )

    count >= @batch_limit
  end
end
