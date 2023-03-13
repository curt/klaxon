defmodule KlaxonWeb.PostsController do
  use KlaxonWeb, :controller
  import KlaxonWeb.Plugs
  import KlaxonWeb.Titles
  alias Klaxon.Profiles.Profile
  alias Klaxon.Contents

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def index(conn, _) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, posts} <-
           Contents.get_posts(profile.uri, conn.assigns[:current_user]) do
      # FIXME: Make title more appropriate.
      render(conn, posts: posts, title: "Posts")
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, id, conn.assigns[:current_user]) do
      render(conn, post: post, title: title(post))
    end
  end

  defp current_profile(conn) do
    case conn.assigns[:current_profile] do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end
end
