defmodule KlaxonWeb.AttachmentController do
  use KlaxonWeb, :controller

  alias Klaxon.Contents
  alias Klaxon.Contents.PostAttachment

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
      changeset = PostAttachment.changeset(%PostAttachment{post: post})
      render(conn, "new.html", changeset: changeset, post: post)
    end
  end

  def create(conn, %{
        "post_id" => post_id,
        "post_attachment" =>
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
      |> put_flash(:info, "Attachment created successfully.")
      |> redirect(to: Routes.attachment_path(conn, :index, post_id))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def edit(conn, %{"post_id" => post_id, "id" => id}) do
    with {:ok, post, attachment} <- get_post_attachment(conn, post_id, id) do
      changeset = PostAttachment.changeset(attachment)

      render(conn, "edit.html",
        changeset: changeset,
        post: post,
        attachment: attachment
      )
    end
  end

  def update(conn, %{"post_id" => post_id, "id" => id, "post_attachment" => params}) do
    with {:ok, _post, attachment} <- get_post_attachment(conn, post_id, id),
         {:ok, _attachment} <- Contents.update_local_post_attachment(attachment, params) do
      conn
      |> put_flash(:info, "Attachment updated successfully.")
      |> redirect(to: Routes.attachment_path(conn, :index, post_id))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete?(conn, %{"post_id" => post_id, "id" => id}) do
    with {:ok, post, attachment} <- get_post_attachment(conn, post_id, id) do
      render(conn, :delete?, post: post, attachment: attachment)
    end
  end

  def delete(conn, %{"post_id" => post_id, "id" => id}) do
    with {:ok, _post, attachment} <- get_post_attachment(conn, post_id, id),
         {:ok, _attachment} <- Contents.delete_post_attachment(attachment) do
      conn
      |> put_flash(:info, "Attachment deleted successfully.")
      |> redirect(to: Routes.attachment_path(conn, :index, post_id))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "delete?.html", changeset: changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_post_attachment(conn, post_id, id) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, post_id, conn.assigns[:current_user]) do
      if attachment = List.first(Enum.filter(post.attachments, fn x -> x.id == id end)) do
        {:ok, post, attachment}
      else
        {:error, :not_found}
      end
    end
  end
end
