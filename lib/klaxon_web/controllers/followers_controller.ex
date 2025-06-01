defmodule KlaxonWeb.FollowersController do
  @moduledoc """
  Provides valid but empty controller responses. Allows definition of routes
  for which other controllers are not yet defined.
  """
  use KlaxonWeb, :controller
  import KlaxonWeb.Plugs
  alias Klaxon.Activities

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def index(%Plug.Conn{private: %{:phoenix_format => "activity+json"}} = conn, _params) do
    with {:ok, %{uri: profile_uri} = _profile} <- current_profile(conn),
         followers = Activities.get_follower_uris(profile_uri) do
      render(conn, :index, followers: followers)
    end
  end

  def index(_, _params) do
    {:error, :not_acceptable}
  end
end
