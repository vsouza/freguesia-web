defmodule Freguesia.Admin.Operator do
  @moduledoc """
  Backoffice operator (`admins` table, PRD §9 and §7).

  Login with email and password (Argon2), followed by TOTP. 2FA is mandatory:
  `totp_confirmed_at` nil means the operator still needs to register the app.
  """
  use Freguesia.Schema

  use Gettext, backend: FreguesiaWeb.Gettext

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

  @doc "Creation changeset: validates and stores the password hash."
  def create_changeset(operator, attrs) do
    operator
    |> cast(attrs, [:email, :password, :role])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: dgettext("errors", "invalid email")
    )
    |> validate_length(:password,
      min: 12,
      max: 72,
      message: dgettext("errors", "use between 12 and 72 characters")
    )
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
