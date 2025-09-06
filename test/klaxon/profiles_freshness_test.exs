defmodule Klaxon.ProfilesFreshnessTest do
  use Klaxon.DataCase, async: false

  alias Klaxon.Repo
  alias Klaxon.Profiles
  alias Klaxon.Profiles.Profile

  test "returns profile when within freshness window" do
    uri = "http://localhost:4002/freshness-within"

    {:ok, %Profile{} = profile} =
      Profiles.insert_or_update_profile_by_uri(uri, %{name: "within", uri: uri})

    fresh_time = DateTime.add(DateTime.utc_now(), -599)
    {:ok, %Profile{} = profile} =
      profile
      |> Ecto.Changeset.change(updated_at: fresh_time)
      |> Repo.update()

    id = profile.id
    assert %Profile{id: ^id} = Profiles.get_public_profile_by_uri(uri)
  end

  test "returns nil when outside freshness window" do
    uri = "http://localhost:4002/freshness-outside"

    {:ok, %Profile{} = profile} =
      Profiles.insert_or_update_profile_by_uri(uri, %{name: "outside", uri: uri})

    stale_time = DateTime.add(DateTime.utc_now(), -601)
    {:ok, %Profile{} = _} =
      profile
      |> Ecto.Changeset.change(updated_at: stale_time)
      |> Repo.update()

    assert Profiles.get_public_profile_by_uri(uri) == nil
  end

end
