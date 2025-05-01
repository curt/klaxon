defmodule KlaxonWeb.CheckinAttachmentController do
  use KlaxonWeb, :controller
  alias Klaxon.Checkins
  alias Klaxon.Checkins.CheckinAttachment
  action_fallback(KlaxonWeb.FallbackController)

  def index(conn, %{"place_id" => place_id, "checkin_id" => checkin_id}) do
    with {:ok, checkin} <-
           Checkins.get_checkin(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id,
             checkin_id
           ) do
      render(conn, place: checkin.place, checkin: checkin)
    end
  end

  def new(conn, %{"place_id" => place_id, "checkin_id" => checkin_id}) do
    with {:ok, checkin} <-
           Checkins.get_checkin(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id,
             checkin_id
           ) do
      changeset = CheckinAttachment.changeset(%Checkins.CheckinAttachment{})
      render(conn, "new.html", changeset: changeset, place: checkin.place, checkin: checkin)
    end
  end

  def create(conn, %{
        "place_id" => place_id,
        "checkin_id" => checkin_id,
        "checkin_attachment" =>
          %{"upload" => %Plug.Upload{path: path, content_type: content_type}} = attachment_params
      }) do
    with {:ok, checkin} <-
           Checkins.get_checkin(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id,
             checkin_id
           ) do
      case Checkins.insert_checkin_attachment(
             checkin_id,
             attachment_params,
             path,
             content_type,
             &Routes.media_url(conn, :show, &1, &2, &3)
           ) do
        {:ok, _checkin_attachment} ->
          conn
          |> put_flash(:info, "Attachment created successfully.")
          |> redirect(to: Routes.checkin_attachment_path(conn, :index, place_id, checkin_id))

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, "new.html", changeset: changeset, place: checkin.place, checkin: checkin)
      end
    end
  end

  def edit(conn, %{
        "place_id" => place_id,
        "checkin_id" => checkin_id,
        "id" => id
      }) do
    with {:ok, checkin} <-
           Checkins.get_checkin(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id,
             checkin_id
           ),
         {:ok, attachment} <-
           Checkins.get_checkin_attachment(id) do
      changeset = CheckinAttachment.changeset(attachment)

      render(conn, "edit.html",
        changeset: changeset,
        place: checkin.place,
        checkin: checkin,
        attachment: attachment
      )
    end
  end

  def update(conn, %{
        "place_id" => place_id,
        "checkin_id" => checkin_id,
        "id" => id,
        "checkin_attachment" => params
      }) do
    with {:ok, checkin} <-
           Checkins.get_checkin(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id,
             checkin_id
           ),
         {:ok, attachment} <-
           Checkins.get_checkin_attachment(id) do
      case Checkins.update_checkin_attachment(
             attachment,
             params
           ) do
        {:ok, _attachment} ->
          conn
          |> put_flash(:info, "Attachment updated successfully.")
          |> redirect(to: Routes.checkin_attachment_path(conn, :index, checkin.place, checkin))

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, "edit.html",
            changeset: changeset,
            place: checkin.place,
            checkin: checkin,
            attachment: attachment
          )
      end
    end
  end

  def delete(conn, %{
        "place_id" => place_id,
        "checkin_id" => checkin_id,
        "id" => id
      }) do
    with {:ok, checkin} <-
           Checkins.get_checkin(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id,
             checkin_id
           ),
         {:ok, attachment} <- Checkins.get_checkin_attachment(id),
         {:ok, _} <- Checkins.delete_checkin_attachment(attachment) do
      conn
      |> put_flash(:info, "Attachment deleted successfully.")
      |> redirect(to: Routes.checkin_attachment_path(conn, :index, checkin.place, checkin))
    end
  end
end
