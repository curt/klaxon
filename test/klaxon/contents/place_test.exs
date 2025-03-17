defmodule Klaxon.Contents.PlaceTest do
  use Klaxon.DataCase, async: true
  alias Klaxon.Contents
  alias Klaxon.Contents.Place
  alias Klaxon.Repo
  alias Klaxon.Profiles.Profile

  defp create_profile(attrs \\ %{}) do
    {:ok, profile} =
      Repo.insert(%Profile{
        uri: Map.get(attrs, :uri, "test-uri"),
        name: Map.get(attrs, :name, "Test Profile")
      })

    profile
  end

  defp create_place(profile, attrs \\ %{}) do
    {:ok, place} =
      Repo.insert(%Place{
        title: Map.get(attrs, :title, "Test Place"),
        uri: Map.get(attrs, :uri, "test-place-uri"),
        lat: Map.get(attrs, :lat, 10.0),
        lon: Map.get(attrs, :lon, 20.0),
        status: Map.get(attrs, :status, :published),
        visibility: Map.get(attrs, :visibility, :public),
        origin: Map.get(attrs, :origin, :local),
        profile_id: profile.id
      })

    place
  end

  describe "get_places/2" do
    test "returns places for a given profile URI" do
      profile = create_profile()
      place = create_place(profile)

      {:ok, places} = Contents.get_places(profile.uri, %{})
      assert length(places) == 1
      assert hd(places).id == place.id
    end
  end

  describe "get_place/3" do
    test "returns a place by ID and profile URI" do
      profile = create_profile()
      place = create_place(profile)

      {:ok, found_place} = Contents.get_place(profile.uri, place.id, %{})
      assert found_place.id == place.id
    end

    test "returns error when place is not found" do
      profile = create_profile()
      assert {:error, :not_found} == Contents.get_place(profile.uri, "nonexistent", %{})
    end
  end

  describe "create_place/2" do
    test "successfully creates a place" do
      profile = create_profile()

      attrs = %{
        title: "Test Place",
        uri: "test-uri",
        lat: 10.0,
        lon: 20.0,
        status: :published,
        visibility: :public,
        origin: :local
      }

      assert {:ok, place} = Contents.create_place(profile, attrs)
      assert place.title == "Test Place"
    end

    test "fails with invalid attributes" do
      profile = create_profile()
      assert {:error, _changeset} = Contents.create_place(profile, %{})
    end
  end

  describe "update_place/3" do
    test "successfully updates a place" do
      profile = create_profile()
      place = create_place(profile)
      attrs = %{title: "Updated Title"}

      assert {:ok, updated_place} = Contents.update_place(profile, place, attrs)
      assert updated_place.title == "Updated Title"
    end

    test "fails when profile does not match" do
      profile1 = create_profile()
      profile2 = create_profile(%{name: "Test Profile 2", uri: "test-uri-2"})
      place = create_place(profile1)
      attrs = %{title: "Updated Title"}

      assert {:error, :unauthorized} == Contents.update_place(profile2, place, attrs)
    end
  end

  describe "delete_place/2" do
    test "successfully deletes a place" do
      profile = create_profile()
      place = create_place(profile)

      assert {:ok, _deleted} = Contents.delete_place(profile, place)
      assert Repo.get(Place, place.id) == nil
    end

    test "fails when profile does not match" do
      profile1 = create_profile()
      profile2 = create_profile(%{name: "Test Profile 2", uri: "test-uri-2"})
      place = create_place(profile1)

      assert {:error, :unauthorized} == Contents.delete_place(profile2, place)
    end
  end
end
