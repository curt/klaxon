defmodule KlaxonWeb.WebfingerController do
  use KlaxonWeb, :controller
  alias Klaxon.Webfinger

  action_fallback KlaxonWeb.FallbackController

  def show(conn, %{"resource" => resource}) do
    case Webfinger.get_webfinger!(resource) do
      {profile, canonical_resource} ->
        render(conn, "show.json", webfinger: profile, resource: canonical_resource)
      _ -> json_status_response(conn, 404, "Not found")
    end
  end

  def show(conn, _) do
    json_status_response(conn, 400, "Bad request")
  end
end
