defmodule Freguesia.Admin.Operator do
  @moduledoc """
  Operador do backoffice (tabela `admins`, PRD §9 e §7).

  Login com e-mail e senha (Argon2), seguido de TOTP. O 2FA é obrigatório:
  `totp_confirmed_at` nil significa que o operador ainda precisa cadastrar o app.
  """
  use Freguesia.Schema

  @roles [:admin, :moderator]

  schema "admins" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :role, Ecto.Enum, values: @roles, default: :moderator
    field :totp_secret, :binary, redact: true
    field :totp_confirmed_at, :utc_datetime

    timestamps()
  end

  @doc "Changeset de criação: valida e grava o hash da senha."
  def create_changeset(operator, attrs) do
    operator
    |> cast(attrs, [:email, :password, :role])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "e-mail inválido")
    |> validate_length(:password, min: 12, max: 72, message: "use entre 12 e 72 caracteres")
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> put_change(:password_hash, Argon2.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end
end
