defmodule KlaxonWeb.RedirectController do
  use KlaxonWeb, :controller

  def post_index_redirect(conn, _) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: Routes.post_path(conn, :index))
  end

  def post_show_redirect(conn, %{"id" => id}) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: Routes.post_path(conn, :show, id))
  end

  def place_show_redirect(conn, %{"id" => id}) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: Routes.place_path(conn, :show, id))
  end
end
