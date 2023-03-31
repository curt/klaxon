defmodule Klaxon.Media do
  require Logger

  alias Ecto.NoResultsError
  alias Ecto.Query.CastError
  alias Klaxon.MediaClient
  alias Klaxon.Repo
  alias Klaxon.Media.Media
  alias Klaxon.Media.Impression

  import Mogrify
  import Ecto.Query

  def get_media_impression(id, scope, usage) do
    try do
      query =
        from i in Impression,
          join: m in Media,
          on: i.media_id == m.id,
          where: m.id == ^id,
          where: m.scope == ^scope,
          where: i.usage == ^usage,
          preload: :media

      {:ok, Repo.one!(query)}
    rescue
      [CastError, NoResultsError] -> {:error, :not_found}
    end
  end

  def insert_media(attrs, path) do
    with {:ok, media} <-
           %Media{}
           |> Media.changeset(attrs)
           |> Repo.insert() do
      insert_impressions(media, path)
    end
  end

  def insert_remote_media(attrs, url) do
    path = Path.join([System.tmp_dir!(), :crypto.hash(:sha256, url) |> Base.encode16()])

    with {:ok, result} <- MediaClient.get(url) do
      if result.status in 200..299 do
        with :ok <- File.write(path, result.body) do
          {_, content_type} = List.keyfind!(result.headers, "content-type", 0)
          insert_media(attrs |> Map.merge(%{uri: url, mime_type: content_type}), path)
          File.rm(path)
        end
      end || {:error, nil}
    end
  end

  def insert_impressions(%Media{} = media, path) do
    with {:ok, attrs} <- create_impression(media.id, path, :raw) do
      media
      |> Ecto.build_assoc(:impressions, attrs)
      |> Repo.insert()
    end
  end

  def create_impression(media_id, path, :raw = usage) do
    with {:ok, %File.Stat{} = info} <- File.stat(path),
         %{height: height, width: width} <- identify(path),
         {:ok, data} <- File.read(path) do
      {:ok,
       %{
         media_id: media_id,
         data: data,
         usage: usage,
         height: height,
         width: width,
         size: info.size
       }}
    end
  end
end
