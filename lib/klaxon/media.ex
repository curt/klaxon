defmodule Klaxon.Media do
  require Logger
  import Mogrify
  alias Klaxon.Repo
  alias Klaxon.Media.Media

  def insert_media(attrs, tmp_file) do
    with {:ok, media} <-
           %Media{}
           |> Media.changeset(attrs)
           |> Repo.insert() do
      insert_impressions(media, tmp_file)
    end
  end

  def insert_impressions(%Media{} = media, tmp_file) do
    with {:ok, attrs} <- create_impression(media.id, tmp_file, :raw) do
      media
      |> Ecto.build_assoc(:impressions, attrs)
      |> Repo.insert()
    end
  end

  def create_impression(media_id, tmp_file, :raw = usage) do
    with {:ok, %File.Stat{} = info} <- File.stat(tmp_file),
         %{height: height, width: width} <- identify(tmp_file),
         {:ok, data} <- File.read(tmp_file) do
      {:ok,
       %{media_id: media_id, data: data, usage: usage, height: height, width: width, size: info.size}}
    end
  end
end
