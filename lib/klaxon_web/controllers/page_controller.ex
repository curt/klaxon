defmodule KlaxonWeb.PageController do
  use KlaxonWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
