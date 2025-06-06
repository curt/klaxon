defmodule Wafflifier do
  require Logger
  import Ecto.Query
  alias ExAws.S3
  alias Klaxon.Media.Impression
  alias Klaxon.Media.Uploader
  alias Klaxon.Repo
  alias Waffle.Storage

  def wafflify() do
    query = from(m in Klaxon.Media.Media)

    case Repo.all(query) do
      [] -> {:error, :no_media}
      media_list -> Enum.map(media_list, &wafflify/1) |> List.flatten()
    end
  end

  def wafflify(media_id) when is_binary(media_id) do
    query = from(m in Klaxon.Media.Media, where: m.id == ^media_id)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      media -> wafflify(media)
    end
  end

  def wafflify(media) when is_map(media) do
    query = from(i in Impression, where: i.media_id == ^media.id)

    case Repo.all(query) do
      [] ->
        {{media.id}, {:error, :no_impressions}}

      impressions ->
        Enum.map(impressions, fn impression ->
          {{media.id, impression.id}, wafflify(media, impression)}
        end)
    end
  end

  def wafflify(_, %{data: nil}), do: :noop

  def wafflify(media, %{id: impression_id, data: data, usage: usage}) when is_map(media) do
    with {:ok, _} <- Uploader.store({%{filename: "", binary: data}, {media, usage}}),
         {:ok, headers} <-
           s3_metadata(s3_bucket(), s3_object_key(media, usage)),
         :ok <- check_etag(headers, one_part_multipart_etag(data)),
         :ok <- check_content_length(headers, byte_size(data)),
         :ok <- check_content_type(headers, media.mime_type),
         {:ok, _} <- clear_data(impression_id) do
      :ok
    end
  end

  defp check_etag(headers, expected_etag) do
    case headers["etag"] do
      nil -> {:error, :etag_missing}
      etag when etag == expected_etag -> :ok
      _ -> {:error, :etag_mismatch}
    end
  end

  defp check_content_length(headers, expected_length) when is_integer(expected_length) do
    expected_value = Integer.to_string(expected_length)

    case headers["content-length"] do
      nil -> {:error, :content_length_missing}
      cl when cl == expected_value -> :ok
      _ -> {:error, :content_length_mismatch}
    end
  end

  defp check_content_type(headers, expected_type) do
    case headers["content-type"] do
      nil -> {:error, :content_type_missing}
      ct when ct == expected_type -> :ok
      _ -> {:error, :content_type_mismatch}
    end
  end

  defp clear_data(impression_id) do
    Repo.transaction(fn ->
      query = from(i in Impression, where: i.id == ^impression_id)

      case Repo.update_all(query, set: [data: nil]) do
        {1, _} -> :ok
        {0, _} -> Repo.rollback(:not_found)
        {n, _} -> Repo.rollback({:too_many_rows, n})
      end
    end)
  end

  defp s3_metadata(bucket, key) do
    with {:ok, %{headers: headers}} <-
           S3.head_object(bucket, key) |> ExAws.request() do
      Logger.debug("S3 metadata for #{bucket}/#{key}: #{inspect(headers)}")

      {:ok,
       headers
       |> Enum.map(fn {k, v} -> {String.downcase(k), v} end)
       |> Enum.into(%{})
       |> Map.take(["content-length", "content-type", "etag"])}
    end
  end

  defp one_part_multipart_etag(binary_data) when is_binary(binary_data) do
    etag =
      :crypto.hash(:md5, :crypto.hash(:md5, binary_data))
      |> Base.encode16(case: :lower)

    "\"#{etag}-1\""
  end

  defp s3_bucket() do
    Uploader.bucket()
    |> resolve_system_env()
  end

  defp s3_object_key(media, usage) do
    Uploader |> Storage.S3.s3_key(nil, {%{file_name: ""}, {media, usage}})
  end

  defp resolve_system_env({:system, env_var}),
    do: System.get_env(env_var) || raise("Environment variable #{env_var} is not set")

  defp resolve_system_env(bucket), do: bucket
end
