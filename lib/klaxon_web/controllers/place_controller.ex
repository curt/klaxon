defmodule KlaxonWeb.PlaceController do
  use KlaxonWeb, :controller
  alias Klaxon.Contents
  alias Klaxon.Contents.Place

  def index(conn, _params) do
    {:ok, places} =
      Contents.get_places(conn.assigns.current_profile.uri, conn.assigns.current_user)

    render(conn, "index.html", places: places, title: "Places")
  end

  def show(conn, %{"id" => id}) do
    case Contents.get_place(conn.assigns.current_profile.uri, id, conn.assigns.current_user) do
      {:ok, place} -> render(conn, "show.html", place: place)
      {:error, :not_found} -> send_resp(conn, :not_found, "Place not found")
    end
  end

  def new(conn, _params) do
    changeset = Place.changeset(%Place{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"place" => place_params}) do
    case Contents.insert_place(
           conn.assigns.current_profile,
           place_params,
           &Routes.place_url(conn, :show, &1)
         ) do
      {:ok, place} -> redirect(conn, to: Routes.place_path(conn, :show, place))
      {:error, changeset} -> render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    case Contents.get_place(conn.assigns.current_profile.uri, id, conn.assigns.current_user) do
      {:ok, place} ->
        render(conn, "edit.html", place: place, changeset: Place.changeset(place, %{}))

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Place not found")
    end
  end

  def update(conn, %{"id" => id, "place" => place_params}) do
    case Contents.get_place(conn.assigns.current_profile.uri, id, conn.assigns.current_user) do
      {:ok, place} ->
        case Contents.update_place(conn.assigns.current_profile, place, place_params) do
          {:ok, updated_place} ->
            redirect(conn, to: Routes.place_path(conn, :show, updated_place))

          {:error, changeset} ->
            render(conn, "edit.html", place: place, changeset: changeset)
        end

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Place not found")
    end
  end

  def delete(conn, %{"id" => id}) do
    case Contents.get_place(conn.assigns.current_profile.uri, id, conn.assigns.current_user) do
      {:ok, place} ->
        case Contents.delete_place(conn.assigns.current_profile, place) do
          {:ok, _} -> redirect(conn, to: Routes.place_path(conn, :index))
          {:error, :unauthorized} -> send_resp(conn, :forbidden, "Unauthorized")
        end

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Place not found")
    end
  end
end
