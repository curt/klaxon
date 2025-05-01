defmodule KlaxonWeb.CheckinController do
  use KlaxonWeb, :controller
  alias Klaxon.Checkins
  alias Klaxon.Contents
  action_fallback KlaxonWeb.FallbackController

  def all(conn, _params) do
    with {:ok, checkins} <-
           Checkins.get_checkins_all(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user
           ) do
      render(conn, "all.html", checkins: checkins)
    end
  end

  def index(conn, %{"place_id" => place_id}) do
    with {:ok, place} <-
           Contents.get_place(
             conn.assigns.current_profile.uri,
             place_id,
             conn.assigns.current_user
           ),
         {:ok, checkins} <-
           Checkins.get_checkins(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id
           ) do
      render(conn, "index.html", place: place, checkins: checkins)
    end
  end

  def show(conn, %{"place_id" => place_id, "id" => id}) do
    with {:ok, place} <-
           Contents.get_place(
             conn.assigns.current_profile.uri,
             place_id,
             conn.assigns.current_user
           ),
         {:ok, checkin} <-
           Checkins.get_checkin(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id,
             id
           ) do
      render(conn, "show.html", place: place, checkin: checkin)
    end
  end

  def new(conn, %{"place_id" => place_id}) do
    with {:ok, place} <-
           Contents.get_place(
             conn.assigns.current_profile.uri,
             place_id,
             conn.assigns.current_user
           ) do
      changeset = Checkins.change_checkin(%Checkins.Checkin{:checked_in_at => DateTime.utc_now()})
      render(conn, "new.html", place: place, changeset: changeset)
    end
  end

  def create(conn, %{"place_id" => place_id, "checkin" => checkin_params}) do
    case Checkins.insert_checkin(
           conn.assigns.current_profile,
           place_id,
           checkin_params,
           &Routes.checkin_url(conn, :show, place_id, &1)
         ) do
      {:ok, _checkin} -> redirect(conn, to: Routes.place_path(conn, :show, place_id))
      {:error, changeset} -> render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, %{"place_id" => place_id, "id" => id}) do
    case Checkins.get_checkin(
           conn.assigns.current_profile.uri,
           conn.assigns.current_user,
           place_id,
           id
         ) do
      {:ok, checkin} ->
        changeset = Checkins.change_checkin(checkin)
        render(conn, "edit.html", place: checkin.place, checkin: checkin, changeset: changeset)

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Checkin not found")
    end
  end

  def update(conn, %{"place_id" => place_id, "id" => id, "checkin" => checkin_params}) do
    case Checkins.get_checkin(
           conn.assigns.current_profile.uri,
           conn.assigns.current_user,
           place_id,
           id
         ) do
      {:ok, checkin} ->
        case Checkins.update_checkin(conn.assigns.current_profile, checkin, checkin_params) do
          {:ok, _updated_checkin} ->
            redirect(conn, to: Routes.place_path(conn, :show, place_id))

          {:error, changeset} ->
            render(conn, "edit.html",
              place: checkin.place,
              checkin: checkin,
              changeset: changeset
            )
        end

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Checkin not found")
    end
  end

  def delete(conn, %{"place_id" => place_id, "id" => id}) do
    case Checkins.get_checkin(
           conn.assigns.current_profile.uri,
           conn.assigns.current_user,
           place_id,
           id
         ) do
      {:ok, checkin} ->
        case Checkins.delete_checkin(conn.assigns.current_profile, checkin) do
          {:ok, _checkin} ->
            redirect(conn, to: Routes.place_path(conn, :show, place_id))

          {:error, _changeset} ->
            send_resp(conn, :internal_server_error, "Error deleting checkin")
        end

      {:error, :not_found} ->
        send_resp(conn, :not_found, "Checkin not found")
    end
  end
end
