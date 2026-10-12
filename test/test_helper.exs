ExUnit.start()

# Reference data is committed outside the sandbox (see Fixtures.reference_data!/0).
Ecto.Adapters.SQL.Sandbox.mode(Freguesia.Repo, :auto)
Freguesia.Fixtures.reference_data!()
Ecto.Adapters.SQL.Sandbox.mode(Freguesia.Repo, :manual)
