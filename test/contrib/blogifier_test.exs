defmodule BlogifierTest do
  use ExUnit.Case

  alias Blogifier.{Entry, Attachment}

  @sample_zip Path.join(["test", "support", "blogifier", "sample.zip"])
  @missing_index_zip Path.join(["test", "support", "blogifier", "missing_index.zip"])
  @bad_json_zip Path.join(["test", "support", "blogifier", "bad_json.zip"])

  test "known UUID converts to expected Base58" do
    uuid = "4f47e030-91f2-49bc-85b2-3371c12ac4e3"
    {:ok, binary} = Ecto.UUID.dump(uuid)
    base58 = Base58Check.encode58(binary)
    # Example output; depends on your encoder
    assert base58 == "AnpKCYhmXQiNuYC3KWMyX8"
    assert is_binary(base58)
    assert byte_size(base58) >= 22
  end

  test "unzipify returns entries as structs with optional fields present" do
    {:ok, _tmpdir, entries} = Blogifier.unzipify(@sample_zip)

    assert is_list(entries)

    assert Enum.all?(entries, fn entry ->
             match?(%Entry{}, entry) and
               Map.has_key?(entry, :slug) and
               Map.has_key?(entry, :lat) and
               Map.has_key?(entry, :attachments)
           end)
  end

  test "attachments are structs and have optional caption field" do
    {:ok, _tmpdir, entries} = Blogifier.unzipify(@sample_zip)
    attachments = entries |> List.first() |> Map.get(:attachments)

    assert is_list(attachments)

    assert Enum.all?(attachments, fn a ->
             match?(%Attachment{}, a) and Map.has_key?(a, :caption)
           end)
  end

  test "entries missing optional fields still contain them as nil or []" do
    {:ok, _tmpdir, [entry | _]} = Blogifier.unzipify(@sample_zip)

    assert Map.has_key?(entry, :slug)
    assert Map.has_key?(entry, :lat)
    assert is_nil(entry.slug) or is_binary(entry.slug)
    assert is_nil(entry.lat) or is_float(entry.lat)
  end

  test "unzipify_and_clean yields tempdir and deletes it afterward" do
    pid = self()

    Blogifier.unzipify_and_clean(@sample_zip, fn tmpdir, entries ->
      assert File.exists?(Path.join(tmpdir, "index.json"))
      send(pid, {:entries_loaded, entries, tmpdir})
    end)

    receive do
      {:entries_loaded, _entries, tmpdir} ->
        refute File.exists?(tmpdir)
    after
      1000 ->
        flunk("did not receive tempdir cleanup confirmation")
    end
  end

  test "all entry and attachment ids are valid UUID binaries" do
    {:ok, _tmpdir, entries} = Blogifier.unzipify(@sample_zip)

    assert Enum.all?(entries, fn entry ->
             {:ok, _} = Ecto.UUID.load(Base58Check.decode58!(entry.id))

             Enum.all?(entry.attachments, fn a ->
               {:ok, _} = Ecto.UUID.load(Base58Check.decode58!(a.id))
             end)
           end)
  end

  test "unzipify returns error when index.json is missing" do
    assert {:error, "index.json not found in extracted folder"} =
             Blogifier.unzipify(@missing_index_zip)
  end

  test "unzipify returns error on invalid JSON" do
    assert {:error, %Jason.DecodeError{}} = Blogifier.unzipify(@bad_json_zip)
  end
end
