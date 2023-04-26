defmodule KlaxonWeb.AttachmentController do
  use KlaxonWeb, :controller

  alias Klaxon.Contents
  alias Klaxon.Contents.Attachment

  action_fallback(KlaxonWeb.FallbackController)

  def index(conn, %{"post_id" => post_id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, post_id, conn.assigns[:current_user]) do
      render(conn, post: post)
    end
  end

  def new(conn, %{"post_id" => post_id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, post_id, conn.assigns[:current_user]) do
      changeset = Attachment.changeset(%Attachment{post: post})
      render(conn, "new.html", changeset: changeset, post: post)
    end
  end

  def create(conn, %{
        "post_id" => post_id,
        "attachment" =>
          %{"upload" => %Plug.Upload{path: path, content_type: content_type}} = attachment_params
      }) do
    with {:ok, _post} <-
           Contents.insert_local_post_attachment(
             post_id,
             attachment_params,
             path,
             content_type,
             &Routes.media_url(conn, :show, &1, &2, &3)
           ) do
      conn
      |> put_flash(:info, "Post created successfully.")
      |> redirect(to: Routes.attachment_path(conn, :index, post_id))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
