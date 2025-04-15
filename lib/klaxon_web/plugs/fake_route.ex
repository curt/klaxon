defmodule KlaxonWeb.Plugs.FakeRoute do
  import Plug.Conn

  def init(opts), do: opts
  def call(conn, _opts), do: halt(conn)
end
