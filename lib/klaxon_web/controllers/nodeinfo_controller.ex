defmodule KlaxonWeb.NodeInfoController do
  use KlaxonWeb, :controller

  action_fallback KlaxonWeb.FallbackController

  def well_known(conn, _params) do
    render(conn, "well_known.json")
  end

  def version(conn, %{"version" => version} = _params) do
    render(conn, "version.json", version: version)
  end
end
