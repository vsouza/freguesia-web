defmodule Freguesia.Reports.Antifraud do
  @moduledoc """
  Anti-fraud for reports (PRD §8 and §13).

    * At most 3 valid reports per device per place in 30 days. The excess
      are marked `valid = false` with reason `device_limit`.
    * Suspicious batch: more than 10 reports from the same /24 within 1 hour. The report that goes over
      the limit is marked `valid = false` with reason `batch_review`, until the operator releases it.

    The /24 is never stored in the clear. An HMAC with a key that changes daily is stored instead, and the
    hash is deleted after 30 days (see `Freguesia.Reports.purge_ip_hashes/1`).
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
  Invalidation reason for a new report, or `nil` if it is valid.
  Queries the reports already stored, before the insert.
  """
  def invalid_reason(device_id, place_id, ip24_hash, now) do
    cond do
      device_limit_reached?(device_id, place_id, now) -> "device_limit"
      batch_suspicious?(ip24_hash, now) -> "batch_review"
      true -> nil
    end
  end

  @doc "Hash of the /24 of an IPv4 address (tuple or string), with a daily salt. `nil` without an IP."
  def ip24_hash(nil), do: nil

  def ip24_hash({a, b, c, _d}), do: ip24_hash("#{a}.#{b}.#{c}")

  def ip24_hash(prefix) when is_binary(prefix) do
    :crypto.mac(:hmac, :sha256, daily_key(Date.utc_today()), prefix)
  end

  @doc "Extracts the /24 from a textual IP (`a.b.c.d`). Outside IPv4, returns `nil`."
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
