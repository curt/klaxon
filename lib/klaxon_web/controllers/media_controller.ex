defmodule KlaxonWeb.MediaController do
  use KlaxonWeb, :controller

  alias Klaxon.Media

  action_fallback KlaxonWeb.FallbackController

  def show(conn, %{"id" => id, "scope" => scope, "usage" => usage}) do
    with {:ok, impression} <- Media.get_media_impression(id, scope, usage) do
      conn
      |> put_resp_content_type(impression.media.mime_type)
      |> put_resp_header("cache-control", "max-age=2628000")
      |> send_resp(200, impression.data)
    end
  end
end
