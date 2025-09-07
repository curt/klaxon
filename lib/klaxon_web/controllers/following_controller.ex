defmodule KlaxonWeb.FollowingController do
  @moduledoc """
  Provides valid but empty controller responses. Allows definition of routes
  for which other controllers are not yet defined.
  """
  use KlaxonWeb, :controller
  import KlaxonWeb.Plugs

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def index(%Plug.Conn{private: %{:phoenix_format => "activity+json"}} = conn, _params) do
    conn
    |> put_view(KlaxonWeb.FollowingView)
    |> render("index.activity+json")
  end

  def index(_, _params) do
    {:error, :not_acceptable}
  end
end
