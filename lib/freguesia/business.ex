defmodule Freguesia.Business do
  @moduledoc """
  Business accounts and their places (PRD §6).

  An account is created or refreshed on sign-in and then only read from the session.
  An account manages the places it is a member of; the one that registers a place
  becomes its owner.
  """
  import Ecto.Query, warn: false

  alias Freguesia.Business.{Account, Membership}
  alias Freguesia.Catalog.Place
  alias Freguesia.Repo

  @doc "Verifies an ID token with the configured identity adapter and returns the account."
  def sign_in(id_token) do
    with {:ok, claims} <- identity().verify(id_token),
         :ok <- not_disabled(claims.uid) do
      upsert_account(claims)
    end
  end

  def identity, do: Application.fetch_env!(:freguesia, :business_identity)

  @doc "True when the Fake identity is configured (dev and test). The e-mail sign-in form only exists then."
  def dev_identity?, do: identity() == Freguesia.Business.Identity.Fake

  @doc """
  Public Firebase web config for the browser (`apiKey`, `authDomain`, `projectId`,
  `appId`), or `nil` when it is not complete. `nil` keeps Google and Apple disabled.
  """
  def firebase_web_config, do: Application.get_env(:freguesia, :firebase_web)

  @doc "Account by id, or `nil`. Invalid ids are `nil` too."
  def get_account(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Account, uuid)
      :error -> nil
    end
  end

  @doc "Places the account manages, excluding removed ones, with their neighborhood and category."
  def places_for(%Account{id: id}) do
    Repo.all(
      from p in Place,
        join: m in Membership,
        on: m.place_id == p.id,
        where: m.business_account_id == ^id and is_nil(p.removed_at),
        order_by: p.name,
        preload: [:neighborhood, :category]
    )
  end

  @doc "The place when the account manages it, otherwise `nil`."
  def get_place_for(%Account{id: id}, place_id) do
    case Ecto.UUID.cast(place_id) do
      {:ok, uuid} ->
        Repo.one(
          from p in Place,
            join: m in Membership,
            on: m.place_id == p.id,
            where: m.business_account_id == ^id and p.id == ^uuid and is_nil(p.removed_at),
            preload: [:neighborhood, :category]
        )

      :error ->
        nil
    end
  end

  @doc "Makes the account the owner of the place. Idempotent."
  def add_owner(account_id, place_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert_all(
      Membership,
      [
        %{
          business_account_id: account_id,
          place_id: place_id,
          role: :owner,
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: :nothing
    )

    :ok
  end

  defp not_disabled(uid) do
    if Repo.exists?(
         from a in Account, where: a.firebase_uid == ^uid and not is_nil(a.disabled_at)
       ),
       do: {:error, :disabled},
       else: :ok
  end

  defp upsert_account(claims) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # The uid and the login time come from the verified token, so they are set on the
    # struct and never cast from params.
    attrs = %{
      email: claims.email,
      name: claims.name,
      avatar_url: claims.picture,
      provider: claims.provider
    }

    %Account{firebase_uid: claims.uid, last_login_at: now}
    |> Ecto.Changeset.cast(attrs, [:email, :name, :avatar_url, :provider])
    |> Ecto.Changeset.validate_required([:firebase_uid])
    |> Repo.insert(
      on_conflict:
        {:replace, [:email, :name, :avatar_url, :provider, :last_login_at, :updated_at]},
      conflict_target: :firebase_uid,
      returning: true
    )
  end
end
