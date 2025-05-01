defmodule Klaxon.Media do
  require Logger

  alias Mogrify.Image
  alias Klaxon.MediaClient
  alias Klaxon.Repo
  alias Klaxon.Media.Media
  alias Klaxon.Media.Impression

  import Mogrify
  import Ecto.Query

  @usages [
    profile: [:raw, :avatar],
    post: [:raw, :full, :gallery, :avatar],
    checkin: [:raw, :full, :gallery]
  ]

  @spec get_media_by_uri_scope(String.t(), atom) :: %Media{} | nil
  def get_media_by_uri_scope(uri, scope) do
    query =
      from m in Media,
        where: m.uri == ^uri,
        where: m.scope == ^scope

    Repo.one(query)
  end

  @spec get_media_impression(String.t(), atom, atom) :: {:ok, %Impression{}} | {:error, atom}
  def get_media_impression(id, scope, usage) do
    query =
      from i in Impression,
        join: m in Media,
        on: i.media_id == m.id,
        where: m.id == ^id,
        where: m.scope == ^scope,
        where: i.usage == ^usage,
        preload: :media

    case Repo.one(query) do
      %Impression{} = impression -> {:ok, impression}
      _ -> {:error, :not_found}
    end
  end

  def get_media(scope) do
    query =
      from m in Media,
        where: m.scope == ^scope

    {:ok, Repo.all(query)}
  end

  @spec insert_media(map(), String.t()) :: {:ok, %Media{}}
  def insert_media(attrs, path) do
    with {:ok, media} <-
           %Media{}
           |> Media.changeset(attrs)
           |> Repo.insert() do
      Logger.info("Inserted #{media.scope} media #{media.uri} as #{media.id}")
      insert_impressions(media, path)
    end
  end

  @spec insert_remote_media(String.t()) :: :ok | nil | {:error, any}
  def insert_remote_media(url) do
    path = Path.join([System.tmp_dir!(), :crypto.hash(:sha256, url) |> Base.encode16()])

    with {:ok, result} <- MediaClient.get(url) do
      if result.status in 200..299 do
        with :ok <- File.write(path, result.body) do
          {_, content_type} = List.keyfind!(result.headers, "content-type", 0)
          insert_media(%{uri: url, mime_type: content_type}, path)
          File.rm(path)
        end
      end
    end || {:error, nil}
  end

  @spec insert_local_media(String.t(), String.t(), atom, fun) :: {:ok, %Media{}} | {:error, any}
  def insert_local_media(path, content_type, scope, url_fun) when is_function(url_fun, 3) do
    id = EctoBase58.generate()
    url = url_fun.(scope, :raw, id)

    {:ok, media} =
      insert_media(
        %{id: id, uri: url, origin: :local, scope: scope, mime_type: content_type},
        path
      )

    :ok = File.rm(path)
    {:ok, media}
  end

  @spec insert_impressions(%Media{}, String.t()) :: {:ok, %Media{}}
  def insert_impressions(%Media{} = media, path) do
    for usage <- @usages[media.scope] do
      {:ok, attrs} = create_impression(media.id, path, usage)

      media
      |> Ecto.build_assoc(:impressions, attrs)
      |> Repo.insert!()
      |> tap(fn i -> Logger.info("Inserted #{i.usage} impression for media #{media.id}") end)
    end

    {:ok, media}
  end

  @spec create_impression(String.t(), String.t(), atom) :: {:ok, map} | {:error, atom}
  def create_impression(media_id, path, usage) do
    path = mogrify_impression(path, usage)

    with {:ok, %File.Stat{} = info} <- File.stat(path),
         %{height: height, width: width} <- identify(path),
         {:ok, data} <- File.read(path) do
      File.rm(path)

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

  @spec mogrify_impression(String.t(), atom) :: String.t()
  def mogrify_impression(path, usage) do
    mogrified_path = mogrify_path(path, usage)

    open(path)
    |> maybe_mogrify(usage)
    |> custom("strip")
    |> save(path: mogrified_path)

    mogrified_path
  end

  defp maybe_mogrify(%Image{} = image, :raw) do
    image
  end

  defp maybe_mogrify(%Image{} = image, :avatar) do
    image |> gravity("Center") |> resize_to_fill("64x64") |> maybe_downscale()
  end

  defp maybe_mogrify(%Image{} = image, :gallery) do
    image |> gravity("Center") |> resize_to_fill("256x256") |> maybe_downscale()
  end

  defp maybe_mogrify(%Image{} = image, :full) do
    image |> resize_to_limit("1024x1024") |> maybe_downscale()
  end

  defp maybe_downscale(%Image{} = image) do
    if image.format == "jpeg" do
      image |> quality("65")
    end || image
  end

  defp mogrify_path(path, usage), do: "#{path}-#{Atom.to_string(usage)}"
end
