defmodule Freguesia.Repo.Migrations.OffersStatusReplaced do
  use Ecto.Migration

  # When a new offer is approved, the previous one leaves the air but stays in history.
  def up do
    drop constraint(:offers, :offers_status_valid)

    create constraint(:offers, :offers_status_valid,
             check: "status IN ('pending','approved','rejected','replaced')"
           )
  end

  def down do
    execute "UPDATE offers SET status = 'rejected' WHERE status = 'replaced'"

    drop constraint(:offers, :offers_status_valid)

    create constraint(:offers, :offers_status_valid,
             check: "status IN ('pending','approved','rejected')"
           )
  end
end
