defmodule Freguesia.Verification do
  @moduledoc """
  Signup, WhatsApp code, automatic checks, queue and decisions (PRD §6 and §7).

  A restaurant's flow:

    1. `submit_signup/1` creates (or updates) the place in `pending` and sends a code.
    2. `confirm_code/2` checks the code and opens the request in the queue.
    3. The operator decides with `approve/3`, `request_changes/3` or `reject/3`.

  Every decision writes `audit_log` in the same transaction and is idempotent: repeating the
  same action does not duplicate the message or the audit row.
  """
  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Freguesia.{Admin, Messaging, Repo}
  alias Freguesia.Catalog.{Category, Neighborhood, Offer, Place, PlaceCoverage, Segment, Text}
  alias Freguesia.Verification.{Checks, Code, Phone, Request, Signup}

  @code_ttl_seconds 10 * 60
  @resend_after_seconds 60
  @max_code_attempts 3
  @rejection_cooldown_days 30

  ## Signup

  @doc """
  Changeset for the signup form, with the validations that depend on the catalog.
  Writes nothing.
  """
  def change_signup(attrs \\ %{}) do
    %Signup{}
    |> Signup.changeset(attrs)
    |> validate_against_catalog()
  end

  @doc """
  Creates or updates the place from the signup and sends the confirmation code.

  Returns `{:ok, place, delivery}`, with `delivery` set to `:sent` or `:failed`
  (the place stays `pending` even if the send fails), or `{:error, changeset}`
  with the form errors.
  """
  def submit_signup(attrs) do
    changeset = change_signup(attrs)

    if changeset.valid? do
      create_signup(changeset)
    else
      {:error, changeset}
    end
  end

  defp create_signup(changeset) do
    form = Changeset.apply_changes(changeset)

    case persist_signup(form) do
      {:ok, place} -> {:ok, place, deliver_code(place)}
      {:error, reason} -> {:error, add_signup_error(changeset, reason)}
    end
  end

  defp persist_signup(form) do
    with {:ok, e164} <- normalize_whatsapp(form) do
      Repo.transact(fn -> save_signup(form, e164) end)
    end
  end

  # If WhatsApp is down, the place stays `pending` and the customer resends later.
  defp deliver_code(place) do
    case issue_code(place) do
      {:ok, _code} -> :sent
      {:error, _reason} -> :failed
    end
  end

  @doc "Resends the code. Only after 60 seconds since the last send."
  def resend_code(place_id) do
    place = Repo.get!(Place, place_id)
    last = last_code(place.id)

    if last && seconds_since(last.inserted_at) < @resend_after_seconds do
      {:error, :too_soon}
    else
      issue_code(place)
    end
  end

  @doc """
  Checks the code. If it matches: marks the code as confirmed and opens the request in the queue.
  If it does not: counts the attempt (3 at most).
  """
  def confirm_code(place_id, input) when is_binary(input) do
    # Returns {:ok, _} even on error: the counted attempt must not be undone by a rollback.
    Repo.transact(fn -> {:ok, attempt_confirmation(place_id, input)} end)
    |> unwrap_transaction()
  end

  defp attempt_confirmation(place_id, input) do
    case current_code(place_id) do
      nil -> {:error, :no_code}
      %Code{} = code -> check_code(code, place_id, input)
    end
  end

  defp check_code(code, place_id, input) do
    cond do
      expired?(code) -> {:error, :expired}
      code.attempts >= @max_code_attempts -> {:error, :too_many_attempts}
      code_matches?(code, place_id, input) -> confirm_and_open_request(code)
      true -> register_failed_attempt(code)
    end
  end

  ## Backoffice queue

  @doc """
  Queue requests, from oldest to newest.

  Filters: `:pending` (new), `:in_review` (under review), `:needs_changes`
  (sent back to the restaurant), `:all`.
  """
  def list_requests(filter \\ :pending) do
    Request
    |> filter_by_status(filter)
    |> order_by([r], asc: r.inserted_at)
    |> preload(place: [:neighborhood, :segment, :category])
    |> Repo.all()
  end

  def count_by_status do
    Request
    |> group_by([r], r.status)
    |> select([r], {r.status, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Request with its place, the neighborhood of each coverage and the offers. `nil` if it does not exist."
  def get_request(id) do
    Request
    |> preload(place: [:neighborhood, :segment, :category, :offers, coverage: :neighborhood])
    |> Repo.get(id)
  end

  @doc "Current automatic checks for the request's place."
  def evaluate_checks(%Request{place: %Place{} = place}) do
    Checks.evaluate(place, open_complaints?(place.id))
  end

  @doc "Marks the request as under review when the operator opens it. Idempotent."
  def start_review(%Request{status: :pending} = request, operator) do
    place = load_place(request.place_id)

    Repo.transact(fn ->
      with {:ok, request} <- update_request(request, :in_review, operator, nil),
           {:ok, _} <-
             Admin.record_audit(
               operator,
               "verification.start_review",
               "place",
               place.id,
               status_of(place),
               %{
                 "status" => "in_review"
               }
             ) do
        {:ok, request}
      end
    end)
  end

  def start_review(%Request{} = request, _operator), do: {:ok, request}

  @doc """
  Approves and publishes the place. Requires all four checks to be ok, or an internal note
  justifying the approval. Triggers the approval message with the page link.
  """
  def approve(%Request{id: id}, operator, note \\ nil) do
    Repo.transact(fn -> {:ok, decide_approval(lock_request!(id), operator, note)} end)
    |> unwrap_transaction()
  end

  defp decide_approval(%Request{status: :approved}, _operator, _note),
    do: {:ok, :already_approved}

  defp decide_approval(%Request{status: :rejected}, _operator, _note),
    do: {:error, :already_decided}

  defp decide_approval(request, operator, note) do
    place = load_place(request.place_id)
    checks = Checks.evaluate(place, open_complaints?(place.id))

    if Checks.all_ok?(checks) or not blank?(note) do
      do_approve(request, place, operator, checks, note)
    else
      {:error, :checks_incomplete}
    end
  end

  @doc "Requests adjustments from the restaurant, with a mandatory reason. Sends the message with the reason."
  def request_changes(%Request{id: id}, operator, reason) do
    Repo.transact(fn -> {:ok, decide_changes(lock_request!(id), operator, reason)} end)
    |> unwrap_transaction()
  end

  defp decide_changes(%Request{status: :needs_changes}, _operator, _reason),
    do: {:ok, :already_requested}

  defp decide_changes(%Request{status: status}, _operator, _reason)
       when status in [:approved, :rejected],
       do: {:error, :already_decided}

  defp decide_changes(request, operator, reason) do
    if blank?(reason) do
      {:error, :reason_required}
    else
      do_request_changes(request, operator, reason)
    end
  end

  defp do_request_changes(request, operator, reason) do
    place = load_place(request.place_id)

    with {:ok, request} <- update_request(request, :needs_changes, operator, reason),
         {:ok, place} <- update_place(place, :needs_changes),
         {:ok, _} <-
           Admin.record_audit(
             operator,
             "verification.request_changes",
             "place",
             place.id,
             status_of(place),
             %{
               "status" => "needs_changes",
               "reason" => reason
             }
           ),
         {:ok, _} <-
           Messaging.enqueue(place.whatsapp_e164, "adjustment_request", %{
             "name" => place.name,
             "reason" => reason
           }) do
      {:ok, request}
    end
  end

  @doc "Rejects the signup, with a mandatory reason. The number may try again after 30 days."
  def reject(%Request{id: id}, operator, reason) do
    Repo.transact(fn -> {:ok, decide_rejection(lock_request!(id), operator, reason)} end)
    |> unwrap_transaction()
  end

  defp decide_rejection(%Request{status: :rejected}, _operator, _reason),
    do: {:ok, :already_rejected}

  defp decide_rejection(%Request{status: :approved}, _operator, _reason),
    do: {:error, :already_decided}

  defp decide_rejection(request, operator, reason) do
    if blank?(reason) do
      {:error, :reason_required}
    else
      do_reject(request, operator, reason)
    end
  end

  defp do_reject(request, operator, reason) do
    place = load_place(request.place_id)

    with {:ok, request} <- update_request(request, :rejected, operator, reason),
         {:ok, place} <- update_place(place, :rejected),
         {:ok, _} <-
           Admin.record_audit(
             operator,
             "verification.reject",
             "place",
             place.id,
             status_of(place),
             %{
               "status" => "rejected",
               "reason" => reason
             }
           ) do
      {:ok, request}
    end
  end

  ## Signup: internals

  defp validate_against_catalog(changeset) do
    changeset
    |> validate_segment_and_category()
    |> validate_pilot_neighborhood(:neighborhood_id)
    |> validate_coverage_in_pilot()
  end

  defp validate_segment_and_category(changeset) do
    case Changeset.get_field(changeset, :segment_id) do
      nil -> changeset
      segment_id -> check_segment(changeset, Repo.get(Segment, segment_id))
    end
  end

  defp check_segment(changeset, nil),
    do: Changeset.add_error(changeset, :segment_id, "tipo inválido")

  defp check_segment(changeset, %Segment{key: "restaurants", id: segment_id}) do
    category_id = Changeset.get_field(changeset, :category_id)

    cond do
      is_nil(category_id) ->
        Changeset.add_error(changeset, :category_id, "escolha o tipo de comida")

      not category_of_segment?(category_id, segment_id) ->
        Changeset.add_error(changeset, :category_id, "tipo de comida inválido")

      true ->
        changeset
    end
  end

  defp check_segment(changeset, %Segment{}), do: changeset

  defp category_of_segment?(category_id, segment_id) do
    Repo.exists?(from c in Category, where: c.id == ^category_id and c.segment_id == ^segment_id)
  end

  defp validate_pilot_neighborhood(changeset, field) do
    case Changeset.get_field(changeset, field) do
      nil ->
        changeset

      id ->
        if pilot_neighborhood?(id),
          do: changeset,
          else: Changeset.add_error(changeset, field, "fora do piloto por enquanto")
    end
  end

  defp validate_coverage_in_pilot(changeset) do
    ids = Changeset.get_field(changeset, :coverage_ids) || []

    if Enum.all?(ids, &pilot_neighborhood?/1),
      do: changeset,
      else: Changeset.add_error(changeset, :coverage_ids, "bairro fora do piloto")
  end

  defp pilot_neighborhood?(id) do
    Repo.exists?(from n in Neighborhood, where: n.id == ^id and n.pilot == true)
  end

  defp normalize_whatsapp(form) do
    case Phone.normalize(form.whatsapp) do
      {:ok, e164} -> {:ok, e164}
      :error -> {:error, {:whatsapp, "use um WhatsApp brasileiro com DDD"}}
    end
  end

  defp save_signup(form, e164) do
    with {:ok, place} <- upsert_place(form, e164),
         :ok <- put_coverage(place, form.coverage_ids),
         :ok <- put_offer(place, form.offer_text) do
      {:ok, place}
    end
  end

  # A phone number has only one active place. Reuses the record if it has not been
  # verified yet; blocks if it is already verified or the rejection is recent.
  defp upsert_place(form, e164) do
    existing = Repo.one(from p in Place, where: p.whatsapp_e164 == ^e164 and is_nil(p.removed_at))
    save_existing_or_new(existing, form, e164)
  end

  defp save_existing_or_new(nil, form, e164), do: insert_place(form, e164)

  defp save_existing_or_new(%Place{status: :verified}, _form, _e164),
    do: {:error, {:whatsapp, "este número já está no catálogo"}}

  defp save_existing_or_new(%Place{status: :rejected} = place, form, _e164),
    do: reuse_rejected(place, form)

  defp save_existing_or_new(%Place{} = place, form, _e164),
    do: update_place_from_signup(place, form)

  defp reuse_rejected(place, form) do
    last_decision = last_rejection_at(place.id) || place.updated_at
    available_at = DateTime.add(to_utc(last_decision), @rejection_cooldown_days * 86_400)

    if DateTime.compare(DateTime.utc_now(), available_at) == :lt do
      {:error,
       {:whatsapp, "este número só pode tentar de novo a partir de #{format_date(available_at)}"}}
    else
      update_place_from_signup(place, form)
    end
  end

  defp insert_place(form, e164) do
    %Place{}
    |> Place.registration_changeset(place_attrs(form, e164))
    |> Changeset.put_change(:slug, unique_slug(form.name))
    |> Changeset.put_change(:status, :pending)
    |> Changeset.put_change(:terms_accepted_at, now())
    |> Repo.insert()
    |> to_place_result()
  end

  defp update_place_from_signup(place, form) do
    place
    |> Place.registration_changeset(place_attrs(form, place.whatsapp_e164))
    |> Changeset.put_change(:status, :pending)
    |> Changeset.put_change(:terms_accepted_at, now())
    |> Repo.update()
    |> to_place_result()
  end

  defp place_attrs(form, e164) do
    %{
      name: form.name,
      segment_id: form.segment_id,
      category_id: form.category_id,
      neighborhood_id: form.neighborhood_id,
      whatsapp_e164: e164,
      delivery_mode: form.delivery_mode
    }
  end

  defp to_place_result({:ok, place}), do: {:ok, place}

  defp to_place_result({:error, %Changeset{} = changeset}) do
    case Keyword.get(changeset.errors, :whatsapp_e164) do
      {msg, _} -> {:error, {:whatsapp, msg}}
      nil -> {:error, {:invalid, changeset}}
    end
  end

  defp put_coverage(place, neighborhood_ids) do
    Repo.delete_all(from c in PlaceCoverage, where: c.place_id == ^place.id)

    rows =
      neighborhood_ids
      |> Enum.uniq()
      |> Enum.map(fn neighborhood_id ->
        %{
          place_id: place.id,
          neighborhood_id: neighborhood_id,
          inserted_at: now(),
          updated_at: now()
        }
      end)

    Repo.insert_all(PlaceCoverage, rows)
    :ok
  end

  defp put_offer(_place, nil), do: :ok

  defp put_offer(place, text) do
    %Offer{place_id: place.id, status: :pending, updated_by_place_at: now()}
    |> Offer.changeset(%{text: text})
    |> Repo.insert()
    |> case do
      {:ok, _offer} -> :ok
      {:error, changeset} -> {:error, {:invalid, changeset}}
    end
  end

  defp unique_slug(name) do
    base = Text.slugify(name)

    if Repo.exists?(from p in Place, where: p.slug == ^base) do
      base <> "-" <> (:crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower))
    else
      base
    end
  end

  # Domain errors become signup form errors, on the right field.
  defp add_signup_error(changeset, {:whatsapp, msg}) do
    Changeset.add_error(changeset, :whatsapp, msg)
  end

  defp add_signup_error(changeset, {:invalid, %Changeset{errors: errors}}) do
    Enum.reduce(errors, changeset, fn {field, {msg, _opts}}, acc ->
      Changeset.add_error(acc, field, msg)
    end)
  end

  ## Code

  defp issue_code(place) do
    code = generate_code()

    {:ok, record} =
      %Code{}
      |> Changeset.change(%{
        place_id: place.id,
        code_hash: hash_code(place.id, code),
        expires_at: DateTime.add(now(), @code_ttl_seconds),
        attempts: 0,
        channel: "whatsapp"
      })
      |> Repo.insert()

    # Deliberately synchronous: the code must not be stored in the oban_jobs table.
    case Messaging.deliver(place.whatsapp_e164, "verification_code", %{"code" => code}) do
      :ok -> {:ok, record}
      {:error, reason} -> {:error, {:delivery_failed, reason}}
    end
  end

  defp generate_code do
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp hash_code(place_id, code) do
    :crypto.mac(:hmac, :sha256, secret(), "#{place_id}:#{code}")
  end

  defp secret do
    :freguesia
    |> Application.fetch_env!(FreguesiaWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end

  defp code_matches?(code, place_id, input) do
    Plug.Crypto.secure_compare(code.code_hash, hash_code(place_id, input))
  end

  defp current_code(place_id) do
    Repo.one(
      from c in Code,
        where: c.place_id == ^place_id and is_nil(c.confirmed_at),
        order_by: [desc: c.inserted_at],
        limit: 1
    )
  end

  defp last_code(place_id) do
    Repo.one(
      from c in Code, where: c.place_id == ^place_id, order_by: [desc: c.inserted_at], limit: 1
    )
  end

  defp expired?(%Code{expires_at: expires_at}) do
    DateTime.compare(now(), expires_at) == :gt
  end

  defp confirm_and_open_request(code) do
    {:ok, _} =
      code
      |> Changeset.change(confirmed_at: now())
      |> Repo.update()

    open_request(code.place_id)
  end

  defp register_failed_attempt(code) do
    {:ok, updated} =
      code
      |> Changeset.change(attempts: code.attempts + 1)
      |> Repo.update()

    case @max_code_attempts - updated.attempts do
      remaining when remaining > 0 -> {:error, {:invalid_code, remaining}}
      _ -> {:error, :too_many_attempts}
    end
  end

  defp open_request(place_id) do
    existing =
      Repo.one(
        from r in Request,
          where: r.place_id == ^place_id and r.status in ^Request.open_statuses(),
          limit: 1
      )

    if existing do
      {:ok, existing}
    else
      %Request{}
      |> Changeset.change(place_id: place_id, status: :pending, checks: %{})
      |> Repo.insert()
    end
  end

  ## Decisions: internals

  defp do_approve(request, place, operator, checks, note) do
    with {:ok, request} <- update_request(request, :approved, operator, note, checks),
         {:ok, place} <-
           place
           |> Place.status_changeset(:verified, %{verified_at: now()})
           |> Repo.update(),
         :ok <- publish_offer(place),
         {:ok, _} <-
           Admin.record_audit(
             operator,
             "verification.approve",
             "place",
             place.id,
             status_of(place),
             %{
               "status" => "verified",
               "checks" => checks,
               "note" => note
             }
           ),
         {:ok, _} <-
           Messaging.enqueue(place.whatsapp_e164, "place_approved", %{
             "name" => place.name,
             "url" => place_url(place)
           }) do
      {:ok, request}
    end
  end

  # The newest pending offer becomes active; the previously active one becomes `replaced`.
  defp publish_offer(place) do
    pending =
      Repo.one(
        from o in Offer,
          where: o.place_id == ^place.id and o.status == :pending,
          order_by: [desc: o.inserted_at],
          limit: 1
      )

    if pending do
      Repo.update_all(
        from(o in Offer, where: o.place_id == ^place.id and o.status == :approved),
        set: [status: :replaced]
      )

      pending
      |> Changeset.change(status: :approved, approved_at: now())
      |> Repo.update!()
    end

    :ok
  end

  defp update_request(request, status, operator, notes, checks \\ nil) do
    attrs =
      %{status: status, decided_by_id: operator && operator.id, decided_at: now()}
      |> Map.merge(if(notes, do: %{notes: notes}, else: %{}))
      |> Map.merge(if(checks, do: %{checks: checks}, else: %{}))

    request
    |> Changeset.change(attrs)
    |> Repo.update()
  end

  defp update_place(place, status) do
    place
    |> Place.status_changeset(status)
    |> Repo.update()
  end

  defp status_of(place), do: %{"status" => to_string(place.status)}

  defp lock_request!(id) do
    Repo.one!(from r in Request, where: r.id == ^id, lock: "FOR UPDATE")
  end

  defp load_place(place_id) do
    Place
    |> preload([:neighborhood, :segment, :category])
    |> Repo.get!(place_id)
  end

  defp open_complaints?(place_id) do
    Repo.exists?(
      from c in "complaints",
        where: c.place_id == type(^place_id, :binary_id) and c.status == "open"
    )
  end

  defp filter_by_status(query, :all), do: query

  defp filter_by_status(query, status) when is_atom(status) do
    where(query, [r], r.status == ^status)
  end

  defp last_rejection_at(place_id) do
    Repo.one(
      from r in Request,
        where: r.place_id == ^place_id and r.status == :rejected,
        select: r.decided_at,
        order_by: [desc: r.decided_at],
        limit: 1
    )
  end

  defp place_url(place) do
    Application.fetch_env!(:freguesia, :public_url) <> "/lugar/" <> place.slug
  end

  ## Utilities

  defp unwrap_transaction({:ok, {:ok, value}}), do: {:ok, value}
  defp unwrap_transaction({:ok, {:error, reason}}), do: {:error, reason}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""

  defp seconds_since(datetime) do
    DateTime.diff(now(), to_utc(datetime))
  end

  defp to_utc(%DateTime{} = dt), do: dt
  defp to_utc(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")

  defp format_date(datetime) do
    datetime |> DateTime.to_date() |> Calendar.strftime("%d/%m/%Y")
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
