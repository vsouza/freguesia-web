defmodule Freguesia.Sponsorships do
  @moduledoc """
  Own ads (PRD §5, §6 and §7). A place asks to show one of its promotions on its own
  details page for up to 7 days. The request is two pending rows: the promotion and the
  placement. Approving publishes both together; rejecting closes both. Every decision
  goes to `audit_log`. Free during the pilot.
  """
  import Ecto.Query, warn: false

  alias Freguesia.{Admin, Repo}
  alias Freguesia.Catalog.{Place, Promotion, Sponsorship}

  @max_days 7
  @day_seconds 86_400

  def max_days, do: @max_days

  @doc """
  Requests an own ad for a place. `attrs` has `"title"`, optional `"body"` and `"days"`
  (1 to #{@max_days}). Returns `{:ok, sponsorship}` or `{:error, errors}`.
  """
  def request_own_ad(%Place{} = place, attrs, now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)

    case validate(attrs) do
      {:ok, form} -> Repo.transact(fn -> insert_request(place, form, now) end)
      {:error, errors} -> {:error, errors}
    end
  end

  defp insert_request(place, %{title: title, body: body, days: days}, now) do
    ends_at = DateTime.add(now, days * @day_seconds, :second)

    with {:ok, promotion} <-
           Repo.insert(%Promotion{
             place_id: place.id,
             title: title,
             body: body,
             starts_at: now,
             ends_at: ends_at,
             status: :pending
           }) do
      Repo.insert(%Sponsorship{
        place_id: place.id,
        promotion_id: promotion.id,
        kind: :own_detail,
        starts_at: now,
        ends_at: ends_at,
        neighborhood_ids: [place.neighborhood_id],
        status: :pending
      })
    end
  end

  defp validate(attrs) do
    title = attrs |> Map.get("title", "") |> to_string() |> String.trim()
    body = attrs |> Map.get("body", "") |> to_string() |> String.trim()
    days = attrs |> Map.get("days", "") |> parse_days()

    errors =
      [
        {String.length(title) < 3 or String.length(title) > 60, :title,
         "must have 3 to 60 characters"},
        {String.length(body) > 280, :body, "must have up to 280 characters"},
        {days == nil or days < 1 or days > @max_days, :days, "must be between 1 and 7 days"}
      ]
      |> Enum.filter(fn {invalid?, _, _} -> invalid? end)
      |> Enum.map(fn {_, field, message} -> {field, message} end)

    if errors == [],
      do: {:ok, %{title: title, body: body, days: days}},
      else: {:error, errors}
  end

  defp parse_days(value) when is_integer(value), do: value

  defp parse_days(value) when is_binary(value) do
    case Integer.parse(value) do
      {days, ""} -> days
      _ -> nil
    end
  end

  defp parse_days(_), do: nil

  @doc "Own ads waiting for moderation, oldest first, with their place and promotion."
  def list_pending do
    Repo.all(
      from s in Sponsorship,
        where: s.status == :pending and s.kind == :own_detail,
        order_by: [asc: s.inserted_at],
        preload: [:promotion, place: [:neighborhood, :category]]
    )
  end

  @doc "Approves the own ad and its promotion together. Idempotent; audited."
  def approve(sponsorship_id, operator) do
    decide(sponsorship_id, operator, :approved, nil)
  end

  @doc "Rejects the own ad and its promotion. A reason is required; audited."
  def reject(sponsorship_id, operator, reason) do
    if String.trim(to_string(reason)) == "",
      do: {:error, :reason_required},
      else: decide(sponsorship_id, operator, :rejected, String.trim(reason))
  end

  defp decide(sponsorship_id, operator, status, reason) do
    Repo.transact(fn ->
      sponsorship =
        Repo.one!(
          from s in Sponsorship,
            where: s.id == ^sponsorship_id,
            lock: "FOR UPDATE",
            preload: [:promotion]
        )

      cond do
        sponsorship.status == status ->
          {:ok, :already_decided}

        sponsorship.status != :pending ->
          {:error, :already_decided}

        true ->
          apply_decision(sponsorship, operator, status, reason)
      end
    end)
  end

  defp apply_decision(sponsorship, operator, status, reason) do
    with {:ok, _} <- sponsorship |> Ecto.Changeset.change(status: status) |> Repo.update(),
         {:ok, _} <-
           sponsorship.promotion |> Ecto.Changeset.change(status: status) |> Repo.update(),
         {:ok, _} <-
           Admin.record_audit(
             operator,
             "sponsorship.#{status}",
             "sponsorship",
             sponsorship.id,
             %{"status" => "pending"},
             %{"status" => to_string(status), "reason" => reason}
           ) do
      {:ok, status}
    end
  end

  @doc """
  The own ad a place shows on its details page at `now`: approved, running and of the
  `own_detail` kind. `nil` when there is none.
  """
  def own_detail_for(place_id, now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)

    Repo.one(
      from s in Sponsorship,
        join: pr in assoc(s, :promotion),
        where:
          s.place_id == ^place_id and s.kind == :own_detail and s.status == :approved and
            pr.status == :approved and s.starts_at <= ^now and s.ends_at >= ^now,
        order_by: [desc: s.starts_at],
        limit: 1,
        preload: [promotion: pr]
    )
  end

  @doc "Own ads a place has requested, newest first (for the business account)."
  def list_for_place(place_id) do
    Repo.all(
      from s in Sponsorship,
        where: s.place_id == ^place_id and s.kind == :own_detail,
        order_by: [desc: s.inserted_at],
        preload: [:promotion]
    )
  end
end
