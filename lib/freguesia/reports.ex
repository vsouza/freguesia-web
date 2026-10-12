defmodule Freguesia.Reports do
  @moduledoc """
  O loop do WhatsApp (PRD §5, "Retorno do WhatsApp", e §8).

    1. `open_whatsapp/3` registra o clique em "Pedir no WhatsApp".
    2. Quando a aba volta ao foco, `pending_open/3` diz se há uma pergunta para fazer
       (abertura de até 2 h, sem resposta).
    3. `answer/3` grava a resposta: "funcionou" com faixa de economia, ou "não
       funcionou" com motivo. Denúncia "número errado ou golpe" também abre caso.

  Relatos inválidos (antifraude) ficam gravados com `valid = false`, mas não
  entram nas estatísticas.
  """
  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Freguesia.Repo
  alias Freguesia.Reports.{Antifraud, Complaint, Open, Report, Savings}

  @pending_window_seconds 2 * 60 * 60
  @complaint_window_days 7
  @complaint_threshold 2
  @report_retention_days 30

  @doc "Registra a abertura. Chamado antes de redirecionar para o `wa.me`."
  def open_whatsapp(place_id, device_id, now \\ now()) do
    %Open{}
    |> Changeset.change(%{place_id: place_id, device_id: device_id, opened_at: now})
    |> Repo.insert()
  end

  @doc """
  Abertura pendente de resposta para este lugar e dispositivo: até 2 h depois
  do clique, e ainda sem resposta. Vale a mais recente.
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
  Grava a resposta de uma abertura.

  `attrs` é `%{outcome: :worked, band: "le10"}` ou `%{outcome: :failed, reason: :no_answer}`.
  `ctx` traz `device_id` e `ip24_hash`. Devolve `{:ok, report}` ou `{:error, motivo}`:
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

  @doc "Abre um caso de denúncia no backoffice."
  def open_complaint(place_id, source, reason, details \\ nil) do
    %Complaint{}
    |> Changeset.change(%{place_id: place_id, source: source, reason: reason, details: details})
    |> Repo.insert()
  end

  @doc """
  Esconde o botão de WhatsApp quando há 2 denúncias abertas em 7 dias.
  Some sozinho quando o operador fecha os casos.
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

  @doc "Apaga o hash do /24 de relatos com mais de 30 dias (PRD §13)."
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
