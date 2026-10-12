defmodule Freguesia.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  # Analytics próprio, particionado por mês (PRD §9).
  # A partição DEFAULT evita erro de insert em mês sem partição; um job mensal
  # (fase 1) cria as próximas partições.
  def up do
    execute """
    CREATE TABLE events (
      id uuid NOT NULL,
      name text NOT NULL,
      props jsonb NOT NULL DEFAULT '{}',
      device_id uuid,
      user_id uuid,
      inserted_at timestamp(0) without time zone NOT NULL,
      updated_at timestamp(0) without time zone NOT NULL,
      PRIMARY KEY (id, inserted_at)
    ) PARTITION BY RANGE (inserted_at)
    """

    execute "CREATE TABLE events_2026_10 PARTITION OF events FOR VALUES FROM ('2026-10-01') TO ('2026-11-01')"

    execute "CREATE TABLE events_2026_11 PARTITION OF events FOR VALUES FROM ('2026-11-01') TO ('2026-12-01')"

    execute "CREATE TABLE events_2026_12 PARTITION OF events FOR VALUES FROM ('2026-12-01') TO ('2027-01-01')"

    execute "CREATE TABLE events_default PARTITION OF events DEFAULT"
  end

  def down do
    drop table(:events)
  end
end
