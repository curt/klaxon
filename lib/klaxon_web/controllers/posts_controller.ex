defmodule KlaxonWeb.PostsController do
  use KlaxonWeb, :controller
  import KlaxonWeb.Plugs
  import KlaxonWeb.Titles
  alias Klaxon.Contents

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def index(conn, _) do
    with {:ok, posts} <-
           Contents.get_posts(Routes.profile_url(conn, :index), conn.assigns.current_user) do
      # FIXME: Make title more appropriate.
      render(conn, posts: posts, title: "Posts")
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, post} <-
           Contents.get_post(Routes.profile_url(conn, :index), id, conn.assigns.current_user) do
      render(conn, post: post, title: title(post))
    end
  end
end
