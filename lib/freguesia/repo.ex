defmodule Freguesia.Repo do
  use Ecto.Repo,
    otp_app: :freguesia,
    adapter: Ecto.Adapters.Postgres
end
