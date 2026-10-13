defmodule Freguesia.Backoffice do
  @moduledoc """
  Operator actions on places, complaints and reports (PRD §7).

  Every action that changes data writes an `audit_log` row in the same transaction,
  with the operator, the state before and after, and the reason when there is one.
  """
  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Freguesia.{Admin, Repo}
  alias Freguesia.Catalog.{Category, Place}
  alias Freguesia.Reports.{Complaint, Report, Stats}

  @open_complaint_statuses [:open, :reviewing]
  @timezone "America/Sao_Paulo"

  ## Places

  @doc "Places for the list screen. `filters`: `:query` (name), `:status`."
  def list_places(filters \\ %{}) do
    Place
    |> filter_name(filters[:query])
    |> filter_status(filters[:status])
    |> order_by([p], asc: p.name)
    |> limit(200)
    |> preload([:segment, :category, :neighborhood])
    |> Repo.all()
  end

  def get_place(id) do
    Place
    |> preload([:segment, :category, :neighborhood])
    |> Repo.get(id)
  end

  @doc "Pauses the place until the end of today in São Paulo (\"not serving today\", PRD §6)."
  def pause_today(%Place{} = place, operator) do
    update_place(place, operator, "place.pause", %{paused_until: end_of_today_sp()}, fn p ->
      %{"paused_until" => p.paused_until}
    end)
  end

  def resume(%Place{} = place, operator) do
    update_place(place, operator, "place.resume", %{paused_until: nil}, fn _ ->
      %{"paused_until" => nil}
    end)
  end

  @doc "Removes the place from the catalog. The reason is required."
  def remove(%Place{} = place, operator, reason) do
    if blank?(reason), do: {:error, :reason_required}, else: do_remove(place, operator, reason)
  end

  defp do_remove(place, operator, reason) do
    before = %{"status" => to_string(place.status)}

    Repo.transact(fn ->
      with {:ok, place} <-
             place |> Place.status_changeset(:removed, %{removed_at: now()}) |> Repo.update(),
           {:ok, _} <-
             Admin.record_audit(operator, "place.remove", "place", place.id, before, %{
               "status" => "removed",
               "reason" => reason
             }) do
        {:ok, place}
      end
    end)
  end

  @doc "Moves the place to another category of its segment (PRD §7)."
  def reassign_category(%Place{} = place, operator, category_id) do
    category = Repo.get(Category, category_id)

    if is_nil(category) or category.segment_id != place.segment_id do
      {:error, :invalid_category}
    else
      update_place(
        place,
        operator,
        "place.reassign_category",
        %{category_id: category.id},
        fn _ ->
          %{"category" => category.key}
        end
      )
    end
  end

  @doc "Places with a `valid = false` report inside the window, for the operator to review."
  def flagged_reports(place_id) do
    Repo.all(
      from r in Report,
        where: r.place_id == ^place_id and r.valid == false,
        order_by: [desc: r.answered_at],
        limit: 50
    )
  end

  @doc "Releases a report held by batch review: it counts again in the statistics."
  def release_report(%Report{} = report, operator) do
    Repo.transact(fn ->
      before = %{"valid" => false, "invalid_reason" => report.invalid_reason}

      with {:ok, report} <-
             report
             |> Changeset.change(valid: true, invalid_reason: nil)
             |> Repo.update(),
           {:ok, _} <-
             Admin.record_audit(operator, "report.release", "report", report.id, before, %{
               "valid" => true
             }) do
        {:ok, report}
      end
    end)
  end

  @doc "Replaces the photo of a place with an already stored key. Audited."
  def replace_photo(%Place{} = place, operator, key) do
    update_place(place, operator, "place.photo", %{photo_key: key}, fn updated ->
      %{"photo_key" => updated.photo_key}
    end)
  end

  def place_stats(place_id), do: Stats.for_place(place_id)

  ## Complaints

  def list_complaints(statuses \\ @open_complaint_statuses) do
    Repo.all(
      from c in Complaint,
        where: c.status in ^statuses,
        order_by: [asc: c.inserted_at],
        preload: [place: [:neighborhood]]
    )
  end

  @doc "Closes a complaint with a resolution note. A closed complaint stops hiding the button."
  def close_complaint(%Complaint{} = complaint, operator, resolution) do
    if blank?(resolution),
      do: {:error, :reason_required},
      else: do_close(complaint, operator, resolution)
  end

  defp do_close(complaint, operator, resolution) do
    before = %{"status" => to_string(complaint.status)}

    Repo.transact(fn ->
      with {:ok, complaint} <-
             complaint
             |> Changeset.change(status: :closed, resolution: resolution)
             |> Repo.update(),
           {:ok, _} <-
             Admin.record_audit(operator, "complaint.close", "complaint", complaint.id, before, %{
               "status" => "closed",
               "resolution" => resolution
             }) do
        {:ok, complaint}
      end
    end)
  end

  ## Internals

  defp update_place(place, operator, action, changes, after_fun) do
    Repo.transact(fn ->
      before = %{"status" => to_string(place.status)} |> Map.merge(before_fields(place, changes))

      with {:ok, updated} <- place |> Changeset.change(changes) |> Repo.update(),
           {:ok, _} <-
             Admin.record_audit(operator, action, "place", place.id, before, after_fun.(updated)) do
        {:ok, updated}
      end
    end)
  end

  defp before_fields(place, changes) do
    Map.new(changes, fn {key, _value} -> {to_string(key), Map.get(place, key) |> normalize()} end)
    |> Map.delete("status")
  end

  defp normalize(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp normalize(value), do: value

  defp end_of_today_sp do
    today = DateTime.utc_now() |> DateTime.shift_zone!(@timezone) |> DateTime.to_date()
    midnight = DateTime.new!(Date.add(today, 1), ~T[00:00:00], @timezone)
    DateTime.shift_zone!(midnight, "Etc/UTC") |> DateTime.truncate(:second)
  end

  defp filter_name(query, nil), do: query
  defp filter_name(query, ""), do: query

  defp filter_name(query, term) do
    where(query, [p], ilike(p.name, ^"%#{term}%"))
  end

  defp filter_status(query, nil), do: query
  defp filter_status(query, "all"), do: query
  defp filter_status(query, status), do: where(query, [p], p.status == ^status)

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
