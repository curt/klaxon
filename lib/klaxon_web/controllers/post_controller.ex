defmodule KlaxonWeb.PostController do
  use KlaxonWeb, :controller

  import KlaxonWeb.Plugs
  import KlaxonWeb.Titles
  alias Klaxon.Contents
  alias Klaxon.Contents.Post

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def index(conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, posts} <-
           Contents.get_posts(profile.uri, conn.assigns[:current_user]) do
      # FIXME: Make title more appropriate.
      render(conn, posts: posts, title: "Posts")
    end
  end

  def new(conn, _params) do
    changeset = Contents.change_post(conn.host, %Post{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"post" => post_params}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.insert_local_post(
             post_params,
             profile.id,
             conn.host,
             &Routes.post_url(conn, :show, &1)
           ) do
      conn
      |> put_flash(:info, "Post created successfully.")
      |> redirect(to: Routes.post_path(conn, :show, post))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, id, conn.assigns[:current_user]) do
      render(conn, post: post, title: title(post))
    end
  end

  def edit(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <- Contents.get_post(profile.uri, id, conn.assigns[:current_user]) do
      changeset = Contents.change_post(conn.host, post)
      render(conn, "edit.html", post: post, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "post" => post_params} = params) do
    IO.inspect(params)
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <- Contents.get_post(profile.uri, id, conn.assigns[:current_user]) do
      case Contents.update_local_post(post, post_params, conn.host) do
        {:ok, post} ->
          conn
          |> put_flash(:info, "Post updated successfully.")
          |> redirect(to: Routes.post_path(conn, :show, post))

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, "edit.html", post: post, changeset: changeset)
      end
    end
  end

  # def delete(conn, %{"id" => id}) do
  #   post = Contents.get_post!(id)
  #   {:ok, _post} = Contents.delete_post(post)

  #   conn
  #   |> put_flash(:info, "Post deleted successfully.")
  #   |> redirect(to: Routes.post_path(conn, :index))
  # end
end
