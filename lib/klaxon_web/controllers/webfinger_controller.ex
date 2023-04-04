defmodule KlaxonWeb.WebfingerController do
  use KlaxonWeb, :controller
  alias Klaxon.Profiles.Profile
  alias Klaxon.Webfinger

  action_fallback KlaxonWeb.FallbackController

  def show(conn, %{"resource" => resource}) do
    with {:ok, {%Profile{} = profile, canonical_resource}} <-
           Webfinger.get_webfinger(Routes.profile_url(conn, :index), resource) do
      render(conn, "show.json", webfinger: profile, resource: canonical_resource)
    end
  end

  def show(_conn, _) do
    {:error, :bad_request}
  end
end
