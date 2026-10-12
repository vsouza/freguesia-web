ExUnit.start()

# Dados de referência ficam commitados, fora do sandbox (ver Fixtures.reference_data!/0).
Ecto.Adapters.SQL.Sandbox.mode(Freguesia.Repo, :auto)
Freguesia.Fixtures.reference_data!()
Ecto.Adapters.SQL.Sandbox.mode(Freguesia.Repo, :manual)
