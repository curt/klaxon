defmodule KlaxonWeb.MediaController do
  use KlaxonWeb, :controller
  alias Klaxon.Media
  alias Klaxon.Media.Uploader

  action_fallback KlaxonWeb.FallbackController

  def index(conn, %{"scope" => scope}) do
    with {:ok, media} <- Media.get_media(scope) do
      render(conn, media: media)
    end
  end

  def show(conn, %{"id" => id, "scope" => scope, "usage" => usage}) do
    with {:ok, impression} <- Media.get_media_impression(id, scope, usage) do
      if impression.data do
        conn
        |> put_resp_content_type(impression.media.mime_type)
        |> put_resp_header("cache-control", "max-age=2628000")
        |> send_resp(200, impression.data)
      else
        conn
        |> put_status(301)
        |> redirect(external: Uploader.url({"", {impression.media, usage}}))
      end
    end
  end
end
