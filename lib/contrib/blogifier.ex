defmodule Blogifier do
  alias __MODULE__.Entry
  alias __MODULE__.Attachment
  alias Klaxon.Contents
  alias Klaxon.Contents.Post
  alias Klaxon.Profiles.Profile
  alias Klaxon.Repo

  defmodule Entry do
    defstruct [
      :id,
      :paths,
      :date,
      :slug,
      :title,
      :source,
      :lat,
      :lon,
      :ele,
      :location,
      :tags,
      :attachments
    ]
  end

  defmodule Attachment do
    defstruct [
      :id,
      :paths,
      :type,
      :file,
      :caption
    ]
  end

  def blogify(zip_path, profile_uri, host, post_uri_fun, attachment_uri_fun) do
    unzipify_and_clean(zip_path, fn tmpdir, entries ->
      blogify_entries(entries, tmpdir, profile_uri, host, post_uri_fun, attachment_uri_fun)
    end)
  end

  defp blogify_entries(entries, tmpdir, profile_uri, host, post_uri_fun, attachment_uri_fun) do
    profile = Repo.get_by!(Profile, uri: profile_uri)

    for entry <- entries do
      uri = post_uri_fun.(entry.id)
      {:ok, published_at, _} = DateTime.from_iso8601(entry.date)

      changeset =
        %Post{
          id: entry.id,
          published_at: published_at,
          uri: uri,
          profile_id: profile.id,
          origin: :local,
          status: :published,
          visibility: :public
        }
        |> Post.changeset(Map.from_struct(entry), host)

      changeset
      |> Repo.insert()

      attachments = blogify_attachments(entry.attachments, tmpdir, entry.id, attachment_uri_fun)

      {:ok, %{entry: entry.id, attachments: attachments}}
    end
  end

  defp blogify_attachments(attachments, tmpdir, post_id, attachment_uri_fun) do
    with {:ok, attachdir} <-
           Briefly.create(type: :directory, prefix: "attach_#{post_id}") do
      for attachment <- attachments do
        path = Path.join([tmpdir, "media", attachment.file])
        attachpath = Path.join(attachdir, attachment.id)
        File.cp(path, attachpath)

        Contents.insert_local_post_attachment(
          post_id,
          %{caption: attachment.caption},
          attachpath,
          attachment.type,
          attachment_uri_fun
        )

        {:ok, %{attachment: attachment.id}}
      end
    end
  end

  def unzipify(zip_path) do
    with {:ok, tmpdir} <- tempify(zip_path),
         index_path = Path.join(tmpdir, "index.json"),
         true <- File.exists?(index_path),
         {:ok, json} <- File.read(index_path),
         {:ok, raw_data} <- Jason.decode(json),
         atomized = atomize_keys(raw_data),
         entries = Enum.map(atomized, &to_entry_struct/1) do
      {:ok, tmpdir, entries}
    else
      {:error, _} = err -> err
      false -> {:error, "index.json not found in extracted folder"}
      _ -> {:error, "Unexpected error"}
    end
  end

  def unzipify_and_clean(zip_path, fun) when is_function(fun, 2) do
    case unzipify(zip_path) do
      {:ok, tmpdir, entries} ->
        try do
          fun.(tmpdir, entries)
        after
          File.rm_rf(tmpdir)
        end

      error ->
        error
    end
  end

  defp tempify(zip_path) do
    case Briefly.create(type: :directory) do
      {:ok, tmpdir} ->
        case :zip.unzip(String.to_charlist(zip_path), cwd: String.to_charlist(tmpdir)) do
          {:ok, _files} -> {:ok, tmpdir}
          {:error, reason} -> {:error, reason}
        end

      error ->
        error
    end
  end

  defp to_entry_struct(map) do
    sanitized =
      map
      |> map_base58_id()
      |> Map.update(:attachments, [], fn list ->
        Enum.map(list, fn att -> to_attachment_struct(att) end)
      end)
      |> Map.update(:paths, [], fn paths -> paths end)
      |> Map.update(:tags, [], fn tags -> tags end)

    struct(Entry, sanitized)
  end

  defp to_attachment_struct(map) do
    sanitized =
      map
      |> map_base58_id()
      |> Map.update(:paths, [], fn paths -> paths end)

    struct(Attachment, sanitized)
  end

  defp atomize_keys(value) when is_map(value) do
    for {k, v} <- value, into: %{} do
      key = if is_binary(k), do: String.to_atom(k), else: k
      {key, atomize_keys(v)}
    end
  end

  defp atomize_keys(value) when is_list(value) do
    Enum.map(value, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  defp map_base58_id(map) do
    map |> Map.put(:id, encode_base58_from_uuid(map.id))
  end

  defp encode_base58_from_uuid(uuid_str) do
    {:ok, uuid} = Ecto.UUID.dump(uuid_str)
    uuid |> Base58Check.encode58()
  end
end
