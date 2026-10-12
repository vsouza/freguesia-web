defmodule Freguesia.Reports do
  @moduledoc """
  The WhatsApp loop (PRD §5, "WhatsApp return", and §8).

    1. `open_whatsapp/3` records the click on "Pedir no WhatsApp".
    2. When the tab regains focus, `pending_open/3` says whether there is a question to ask
       (an opening up to 2 h old, with no answer).
    3. `answer/3` records the answer: "funcionou" with a savings band, or "não
       funcionou" with a reason. A complaint "número errado ou golpe" also opens a case.

  Invalid reports (anti-fraud) are stored with `valid = false`, but do not
  count toward the stats.
  """
  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Freguesia.Repo
  alias Freguesia.Reports.{Antifraud, Complaint, Open, Report, Savings}

  @pending_window_seconds 2 * 60 * 60
  @complaint_window_days 7
  @complaint_threshold 2
  @report_retention_days 30

  @doc "Records the opening. Called before redirecting to `wa.me`."
  def open_whatsapp(place_id, device_id, now \\ now()) do
    %Open{}
    |> Changeset.change(%{place_id: place_id, device_id: device_id, opened_at: now})
    |> Repo.insert()
  end

  @doc """
  Opening awaiting an answer for this place and device: up to 2 h after
  the click, and still unanswered. The most recent one counts.
  """
  def pending_open(place_id, device_id, now \\ now()) do
    since = DateTime.add(now, -@pending_window_seconds)

    Repo.one(
      from o in Open,
        where:
          o.place_id == ^place_id and o.device_id == ^device_id and o.opened_at >= ^since and
            is_nil(o.responded_at),
        order_by: [desc: o.opened_at],
        limit: 1
    )
  end

  @doc """
  Stores the answer to an opening.

  `attrs` is `%{outcome: :worked, band: "le10"}` or `%{outcome: :failed, reason: :no_answer}`.
  `ctx` carries `device_id` and `ip24_hash`. Returns `{:ok, report}` or `{:error, reason}`:
  `:already_answered`, `:expired`, `:invalid_band`, `:invalid_reason`.
  """
  def answer(open_id, attrs, ctx, now \\ now()) do
    Repo.transact(fn ->
      open = Repo.one!(from o in Open, where: o.id == ^open_id, lock: "FOR UPDATE")

      cond do
        open.responded_at -> {:ok, {:error, :already_answered}}
        expired?(open, now) -> {:ok, {:error, :expired}}
        true -> {:ok, insert_answer(open, attrs, ctx, now)}
      end
    end)
    |> case do
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, {:ok, report}} -> {:ok, report}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_answer(open, attrs, ctx, now) do
    with {:ok, fields} <- answer_fields(attrs) do
      invalid = Antifraud.invalid_reason(ctx.device_id, open.place_id, ctx.ip24_hash, now)

      report =
        %Report{}
        |> Changeset.change(
          Map.merge(fields, %{
            open_id: open.id,
            place_id: open.place_id,
            device_id: ctx.device_id,
            ip24_hash: ctx.ip24_hash,
            valid: is_nil(invalid),
            invalid_reason: invalid,
            weight: Decimal.new("1.0"),
            answered_at: now
          })
        )
        |> Repo.insert!()

      open |> Changeset.change(responded_at: now) |> Repo.update!()

      if report.fail_reason == :wrong_or_scam,
        do: open_complaint(open.place_id, :report, :wrong_or_scam)

      {:ok, report}
    end
  end

  defp answer_fields(%{outcome: :worked, band: band}) do
    if Savings.valid_band?(band),
      do: {:ok, %{outcome: :worked, savings_band: band, fail_reason: nil}},
      else: {:error, :invalid_band}
  end

  defp answer_fields(%{outcome: :failed, reason: reason}) do
    if reason in Report.fail_reasons(),
      do: {:ok, %{outcome: :failed, savings_band: nil, fail_reason: reason}},
      else: {:error, :invalid_reason}
  end

  defp answer_fields(_), do: {:error, :invalid_reason}

  defp expired?(%Open{opened_at: opened_at}, now) do
    DateTime.diff(now, opened_at) > @pending_window_seconds
  end

  @doc "Opens a complaint case in the backoffice."
  def open_complaint(place_id, source, reason, details \\ nil) do
    %Complaint{}
    |> Changeset.change(%{place_id: place_id, source: source, reason: reason, details: details})
    |> Repo.insert()
  end

  @doc """
  Hides the WhatsApp button when there are 2 open complaints within 7 days.
  It goes away on its own when the operator closes the cases.
  """
  def whatsapp_hidden?(place_id, now \\ now()) do
    since = DateTime.add(now, -@complaint_window_days * 86_400)

    count =
      Repo.aggregate(
        from(c in Complaint,
          where:
            c.place_id == ^place_id and c.status in [:open, :reviewing] and
              c.inserted_at >= ^since
        ),
        :count
      )

    count >= @complaint_threshold
  end

  @doc "Deletes the /24 hash of reports older than 30 days (PRD §13)."
  def purge_ip_hashes(now \\ now()) do
    cutoff = DateTime.add(now, -@report_retention_days * 86_400)

    {count, _} =
      Repo.update_all(
        from(r in Report, where: not is_nil(r.ip24_hash) and r.answered_at < ^cutoff),
        set: [ip24_hash: nil]
      )

    count
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
