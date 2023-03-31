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
    for usage <- [:raw, :avatar] do
      {:ok, attrs} = create_impression(media.id, path, usage)

      media
      |> Ecto.build_assoc(:impressions, attrs)
      |> Repo.insert!()
    end

    {:ok, media}
  end

  def create_impression(media_id, path, usage) do
    path = maybe_mogrify_impression(path, usage)

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

  def maybe_mogrify_impression(path, :avatar), do: mogrify_resize(path, :avatar, "64x64")

  def maybe_mogrify_impression(path, :raw), do: mogrify_noop(path)

  defp mogrify_resize(path, usage, dimensions) do
    new_path = mogrify_path(path, usage)
    open(path) |> resize_to_fill(dimensions) |> save(path: new_path)
    new_path
  end

  defp mogrify_noop(path) do
    new_path = mogrify_path(path, :raw)
    {:ok, _} = File.copy(path, new_path)
    new_path
  end

  defp mogrify_path(path, usage), do: "#{path}-#{Atom.to_string(usage)}"
end
