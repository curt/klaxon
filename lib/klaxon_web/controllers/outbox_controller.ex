defmodule KlaxonWeb.OutboxController do
  @moduledoc """
  Provides valid but empty controller responses. Allows definition of routes
  for which other controllers are not yet defined.
  """
  use KlaxonWeb, :controller
  alias Klaxon.Contents
  import KlaxonWeb.Plugs

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def index(%Plug.Conn{private: %{:phoenix_format => "activity+json"}} = conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, posts} <-
           Contents.get_posts(profile.uri, nil, limit: 10) do
      render(conn, :index, posts: posts)
    end
  end

  def index(_, _params) do
    {:error, :not_acceptable}
  end
end
