defmodule Freguesia.Admin do
  @moduledoc """
  Backoffice: operators, password, 2FA (TOTP) and `audit_log` (PRD §7).

  The operator session lives in the signed and encrypted Plug cookie. It expires
  after 8 hours, and the operator is reloaded from the database on every request, so
  deactivating an operator takes effect immediately.
  """
  import Ecto.Query, warn: false

  alias Freguesia.Admin.{AuditEntry, Operator}
  alias Freguesia.Repo

  @session_ttl_seconds 8 * 60 * 60
  @totp_issuer "Freguesia"

  ## Operators

  def create_operator(attrs) do
    %Operator{}
    |> Operator.create_changeset(attrs)
    |> Repo.insert()
  end

  def get_operator(id), do: Repo.get(Operator, id)

  @doc """
  Checks the email and password. Always runs the hash, even without a user, so as not to
  reveal which emails exist through response timing.
  """
  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    operator = Repo.get_by(Operator, email: String.downcase(String.trim(email)))

    cond do
      operator && Argon2.verify_pass(password, operator.password_hash) ->
        {:ok, operator}

      operator ->
        {:error, :invalid}

      true ->
        _ = Argon2.no_user_verify()
        {:error, :invalid}
    end
  end

  def authenticate(_, _), do: {:error, :invalid}

  ## TOTP

  @doc """
  Prepares the authenticator app enrollment. Reuses the secret if it already
  exists and is not yet confirmed, so that reloading the page does not invalidate
  what was already scanned. Returns the operator and the `otpauth://` URI.
  """
  def start_totp_enrollment(%Operator{totp_secret: nil} = operator) do
    with {:ok, operator} <-
           operator
           |> Ecto.Changeset.change(totp_secret: NimbleTOTP.secret(), totp_confirmed_at: nil)
           |> Repo.update() do
      {:ok, operator, totp_uri(operator)}
    end
  end

  def start_totp_enrollment(%Operator{totp_confirmed_at: nil} = operator) do
    {:ok, operator, totp_uri(operator)}
  end

  def start_totp_enrollment(%Operator{} = operator), do: {:error, {:already_enrolled, operator}}

  defp totp_uri(%Operator{email: email, totp_secret: secret}) do
    NimbleTOTP.otpauth_uri(@totp_issuer <> ":" <> email, secret, issuer: @totp_issuer)
  end

  @doc "Confirms the enrollment with an app code. After this, 2FA is required."
  def confirm_totp_enrollment(%Operator{totp_secret: secret} = operator, code)
      when is_binary(secret) do
    if valid_totp_code?(secret, code) do
      operator
      |> Ecto.Changeset.change(totp_confirmed_at: now())
      |> Repo.update()
    else
      {:error, :invalid_code}
    end
  end

  def confirm_totp_enrollment(_operator, _code), do: {:error, :not_enrolled}

  @doc "Checks the TOTP code of an already registered operator."
  def verify_totp(%Operator{totp_secret: secret, totp_confirmed_at: confirmed} = operator, code)
      when is_binary(secret) and not is_nil(confirmed) do
    if valid_totp_code?(secret, code), do: {:ok, operator}, else: {:error, :invalid_code}
  end

  def verify_totp(_operator, _code), do: {:error, :not_enrolled}

  defp valid_totp_code?(secret, code) when is_binary(code) do
    String.match?(code, ~r/^\d{6}$/) and NimbleTOTP.valid?(secret, code)
  end

  defp valid_totp_code?(_secret, _code), do: false

  ## Session

  @doc "The session operator, if the session is still within 8 hours."
  def fetch_session_operator(%{"operator_id" => id, "operator_at" => at})
      when is_binary(id) and is_integer(at) do
    if now_unix() - at <= @session_ttl_seconds, do: get_operator(id), else: nil
  end

  def fetch_session_operator(_session), do: nil

  def session_ttl_seconds, do: @session_ttl_seconds

  ## Audit log

  @doc """
  Writes a row to `audit_log`. Use it inside the same transaction as the audited action,
  so that the action and the record stay together.
  """
  def record_audit(operator_or_nil, action, entity, entity_id, before, after_state) do
    %AuditEntry{}
    |> Ecto.Changeset.change(%{
      admin_id: operator_id(operator_or_nil),
      action: action,
      entity: entity,
      entity_id: to_string(entity_id),
      before: before,
      after: after_state
    })
    |> Repo.insert()
  end

  defp operator_id(%Operator{id: id}), do: id
  defp operator_id(nil), do: nil

  def audit_entries(entity, entity_id) do
    AuditEntry
    |> where([a], a.entity == ^entity and a.entity_id == ^to_string(entity_id))
    |> order_by([a], asc: a.inserted_at)
    |> Repo.all()
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp now_unix, do: System.system_time(:second)
end
