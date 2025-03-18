defmodule Klaxon.Contents.PlaceTest do
  alias Ecto.UUID
  use Klaxon.DataCase, async: true
  import Mox
  alias Klaxon.Contents
  alias Klaxon.Contents.Post
  alias Klaxon.Contents.PostPlace
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

  defp create_post(profile, attrs) do
    {:ok, post} =
      Repo.insert(%Post{
        context_uri: UUID.generate(),
        uri: Map.get(attrs, :uri, UUID.generate()),
        location: Map.get(attrs, :location, nil),
        lat: Map.get(attrs, :lat, nil),
        lon: Map.get(attrs, :lon, nil),
        profile_id: profile.id
      })

    post
  end

  setup :verify_on_exit!

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

  describe "maybe_associate_posts_with_post_place/1" do
    setup do
      Mox.stub(Klaxon.ContentsMock, :maybe_associate_post_with_place, fn _post, _uri_fun ->
        {:ok, %Klaxon.Contents.PostPlace{}}
      end)

      Application.put_env(:klaxon, :contents_module, Klaxon.ContentsMock)

      profile = create_profile()
      post_without_place = create_post(profile, %{location: "Test Place", lat: 10.0, lon: 20.0})
      post_with_place = create_post(profile, %{location: "Another Place", lat: 30.0, lon: 40.0})

      {:ok, post_without_place: post_without_place, post_with_place: post_with_place}
    end

    test "associates a post without a post_place", %{post_without_place: post} do
      uri_fun = fn x -> "http://example.com/#{x}" end

      # Mock maybe_associate_post_with_place/2 to return a new PostPlace
      Klaxon.ContentsMock
      |> stub(:maybe_associate_post_with_place, fn _post, _uri_fun ->
        {:ok, %PostPlace{place_id: "new_place"}}
      end)

      result = Contents.maybe_associate_posts_with_post_place(uri_fun)
      assert {post.id, :ok, "new_place"} in result
    end

    test "does not modify posts that already have post_places", %{post_with_place: post} do
      uri_fun = fn x -> "http://example.com/#{x}" end
      result = Contents.maybe_associate_posts_with_post_place(uri_fun)
      assert {post.id, :ok, nil} in result
    end

    test "handles missing fields error", %{post_without_place: post} do
      uri_fun = fn x -> "http://example.com/#{x}" end

      Klaxon.ContentsMock
      |> stub(:maybe_associate_post_with_place, fn _post, _uri_fun ->
        {:error, :missing_fields}
      end)

      result = Contents.maybe_associate_posts_with_post_place(uri_fun)
      assert {post.id, :ok, nil} in result
    end

    test "handles changeset errors", %{post_without_place: post} do
      uri_fun = fn x -> "http://example.com/#{x}" end
      changeset = %Ecto.Changeset{valid?: false}

      Klaxon.ContentsMock
      |> stub(:maybe_associate_post_with_place, fn _post, _uri_fun ->
        {:error, changeset}
      end)

      result = Contents.maybe_associate_posts_with_post_place(uri_fun)
      assert {post.id, :error, changeset} in result
    end
  end

  describe "maybe_associate_post_with_place/2" do
    setup do
      profile = create_profile()
      place = create_place(profile, %{title: "Test Place"})

      post_with_location =
        create_post(profile, %{
          uri: "http://example.com/with",
          location: "Test Place",
          lat: 10.0,
          lon: 20.0
        })

      post_without_location =
        create_post(profile, %{uri: "http://example.com/without", lat: 10.0, lon: 20.0})

      {:ok,
       place: place,
       post_with_location: post_with_location,
       post_without_location: post_without_location}
    end

    test "associates post with existing place", %{post_with_location: post, place: _place} do
      uri_fun = fn x -> "http://example.com/#{x}" end
      result = Contents.maybe_associate_post_with_place(post, uri_fun)
      assert {:ok, %PostPlace{}} = result
    end

    test "creates a new place if no matching place exists", %{post_with_location: post} do
      uri_fun = fn x -> "http://example.com/#{x}" end
      # Ensure no place exists
      Repo.delete_all(Place)
      result = Contents.maybe_associate_post_with_place(post, uri_fun)
      assert {:ok, %PostPlace{}} = result
    end

    test "returns error when post lacks location", %{post_without_location: post} do
      uri_fun = fn x -> "http://example.com/#{x}" end
      result = Contents.maybe_associate_post_with_place(post, uri_fun)
      assert {:error, :missing_fields} = result
    end
  end
end
