defmodule KlaxonWeb.Api.PostController do
  use KlaxonWeb, :controller
  alias Klaxon.Contents

  def index(conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, posts} <-
           Contents.get_posts(profile.uri, conn.assigns.current_user) do
      conn
      |> json(posts |> Enum.map(fn p -> struct(Klaxon.Contents.PostList, Map.from_struct(p)) end))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, id, conn.assigns.current_user) do
      conn
      |> json(struct(Klaxon.Contents.Post, Map.from_struct(post)))
    end
  end
end
