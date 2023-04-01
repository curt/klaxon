defmodule KlaxonWeb.WebfingerController do
  use KlaxonWeb, :controller
  alias Klaxon.Profiles.Profile
  alias Klaxon.Webfinger

  action_fallback KlaxonWeb.FallbackController

  def show(conn, %{"resource" => resource}) do
    with {:ok, %Profile{} = current_profile} <- current_profile(conn),
         {:ok, {%Profile{} = profile, canonical_resource}} <-
           Webfinger.get_webfinger(current_profile, resource) do
      render(conn, "show.json", webfinger: profile, resource: canonical_resource)
    end
  end

  def show(_conn, _) do
    {:error, :bad_request}
  end
end
