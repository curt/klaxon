ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Klaxon.Repo, :manual)

Mox.defmock(Klaxon.ContentsMock, for: Klaxon.Contents)
