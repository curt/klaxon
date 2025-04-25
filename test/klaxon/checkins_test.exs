defmodule Klaxon.CheckinsTest do
  use Klaxon.DataCase

  alias Klaxon.Checkins
  alias Klaxon.Checkins.Checkin
  alias Klaxon.Profiles.Profile
  alias Klaxon.Contents.Place
  alias Klaxon.Auth.User
  alias Klaxon.Repo
  alias Ecto.UUID

  # import Klaxon.CheckinsFixtures

  # Add these helper functions for testing authenticated access

  defp create_user(attrs \\ %{}) do
    {:ok, user} =
      Repo.insert(%User{
        id: Map.get(attrs, :id, UUID.generate()),
        email: Map.get(attrs, :email, "test@example.com"),
        hashed_password: Map.get(attrs, :hashed_password, "hashed_password")
      })

    user
  end

  defp create_profile(user \\ nil, attrs \\ %{}) do
    user = user || create_user()

    {:ok, profile} =
      Repo.insert(%Profile{
        uri: Map.get(attrs, :uri, "test-profile-uri"),
        name: Map.get(attrs, :name, "Test Profile"),
        owner_id: user.id
      })

    {profile, user}
  end

  defp create_place(profile, attrs \\ %{}) do
    {:ok, place} =
      Repo.insert(%Place{
        id: Map.get(attrs, :id, EctoBase58.generate()),
        title: Map.get(attrs, :title, "Test Place"),
        uri: Map.get(attrs, :uri, "test-place-uri"),
        status: Map.get(attrs, :status, :published),
        visibility: Map.get(attrs, :visibility, :public),
        origin: Map.get(attrs, :origin, :local),
        lat: 40.0,
        lon: -74.0,
        profile_id: profile.id
      })

    place
  end

  defp create_checkin(profile, place, attrs) do
    {:ok, checkin} =
      Repo.insert(%Checkin{
        id: Map.get(attrs, :id, EctoBase58.generate()),
        checked_in_at: Map.get(attrs, :checked_in_at, DateTime.utc_now()),
        content_html: Map.get(attrs, :content_html, "<p>Test checkin</p>"),
        origin: Map.get(attrs, :origin, :local),
        published_at: Map.get(attrs, :published_at, DateTime.utc_now()),
        source: Map.get(attrs, :source, "test source"),
        status: Map.get(attrs, :status, :published),
        uri: Map.get(attrs, :uri, "test-checkin-uri-#{EctoBase58.generate()}"),
        visibility: Map.get(attrs, :visibility, :public),
        profile_id: profile.id,
        place_id: place.id
      })

    checkin
  end

  describe "get_checkins/4" do
    test "returns all checkins when user is the profile owner" do
      # Create profile with owner
      {profile, owner_user} = create_profile()
      place = create_place(profile)

      # Create checkins with different visibilities
      public_checkin = create_checkin(profile, place, %{visibility: :public})
      unlisted_checkin = create_checkin(profile, place, %{visibility: :unlisted})
      private_checkin = create_checkin(profile, place, %{visibility: :private})

      # Owner should see all checkins
      {:ok, checkins} = Checkins.get_checkins(profile.uri, owner_user, place.id)

      assert length(checkins) == 3
      checkin_ids = Enum.map(checkins, & &1.id)
      assert public_checkin.id in checkin_ids
      assert unlisted_checkin.id in checkin_ids
      assert private_checkin.id in checkin_ids
    end

    test "returns only public checkins when user is not the profile owner" do
      # Create profile with owner
      {profile, _owner_user} = create_profile()
      place = create_place(profile)

      # Create a different user
      non_owner_user = create_user(%{email: "non-owner@example.com"})

      # Create checkins with different visibilities
      public_checkin = create_checkin(profile, place, %{visibility: :public})
      _unlisted_checkin = create_checkin(profile, place, %{visibility: :unlisted})
      _private_checkin = create_checkin(profile, place, %{visibility: :private})

      # Non-owner should only see public checkins in lists
      {:ok, checkins} = Checkins.get_checkins(profile.uri, non_owner_user, place.id)

      assert length(checkins) == 1
      assert hd(checkins).id == public_checkin.id
    end

    test "returns only public checkins when user is nil" do
      # Create profile with owner
      {profile, _owner_user} = create_profile()
      place = create_place(profile)

      # Create checkins with different visibilities
      public_checkin = create_checkin(profile, place, %{visibility: :public})
      _unlisted_checkin = create_checkin(profile, place, %{visibility: :unlisted})
      _private_checkin = create_checkin(profile, place, %{visibility: :private})

      # Nil user should only see public checkins
      {:ok, checkins} = Checkins.get_checkins(profile.uri, nil, place.id)

      assert length(checkins) == 1
      assert hd(checkins).id == public_checkin.id
    end

    test "returns only published checkins for non-owners" do
      {profile, _owner_user} = create_profile()
      place = create_place(profile)

      # Create published and draft checkins
      published_checkin =
        create_checkin(profile, place, %{status: :published, visibility: :public})

      _draft_checkin = create_checkin(profile, place, %{status: :draft, visibility: :public})

      {:ok, checkins} = Checkins.get_checkins(profile.uri, nil, place.id)

      assert length(checkins) == 1
      assert hd(checkins).id == published_checkin.id
    end
  end

  describe "get_checkin/5" do
    test "returns the checkin when user is the profile owner regardless of visibility" do
      {profile, owner_user} = create_profile()
      place = create_place(profile)

      private_checkin = create_checkin(profile, place, %{visibility: :private})

      # Owner should see private checkin
      {:ok, found_checkin} =
        Checkins.get_checkin(profile.uri, owner_user, place.id, private_checkin.id)

      assert found_checkin.id == private_checkin.id
    end

    test "returns public checkin when user is not the profile owner" do
      {profile, _owner_user} = create_profile()
      place = create_place(profile)
      non_owner_user = create_user(%{email: "non-owner@example.com"})

      public_checkin = create_checkin(profile, place, %{visibility: :public})

      {:ok, found_checkin} =
        Checkins.get_checkin(profile.uri, non_owner_user, place.id, public_checkin.id)

      assert found_checkin.id == public_checkin.id
    end

    test "returns unlisted checkin when user is not the profile owner" do
      {profile, _owner_user} = create_profile()
      place = create_place(profile)
      non_owner_user = create_user(%{email: "non-owner@example.com"})

      unlisted_checkin = create_checkin(profile, place, %{visibility: :unlisted})

      {:ok, found_checkin} =
        Checkins.get_checkin(profile.uri, non_owner_user, place.id, unlisted_checkin.id)

      assert found_checkin.id == unlisted_checkin.id
    end

    test "returns error not found for private checkin when user is not the profile owner" do
      {profile, _owner_user} = create_profile()
      place = create_place(profile)
      non_owner_user = create_user(%{email: "non-owner@example.com"})

      private_checkin = create_checkin(profile, place, %{visibility: :private})

      {:error, :not_found} =
        Checkins.get_checkin(profile.uri, non_owner_user, place.id, private_checkin.id)
    end

    test "returns error not found for private checkin when user is nil" do
      {profile, _owner_user} = create_profile()
      place = create_place(profile)

      private_checkin = create_checkin(profile, place, %{visibility: :private})

      {:error, :not_found} = Checkins.get_checkin(profile.uri, nil, place.id, private_checkin.id)
    end

    test "returns error not found for non-existent checkin" do
      {profile, user} = create_profile()
      place = create_place(profile)

      {:error, :not_found} =
        Checkins.get_checkin(profile.uri, user, place.id, "X3eujqMz7fRRPEwxeVRHap")
    end
  end

  # describe "checkins" do
  #   @invalid_attrs %{
  #     status: nil,
  #     origin: nil,
  #     source: nil,
  #     uri: nil,
  #     content_html: nil,
  #     visibility: nil,
  #     published_at: nil
  #   }

  #   test "list_checkins/0 returns all checkins" do
  #     checkin = checkin_fixture()
  #     assert Checkins.list_checkins() == [checkin]
  #   end

  #   test "get_checkin!/1 returns the checkin with given id" do
  #     checkin = checkin_fixture()
  #     assert Checkins.get_checkin!(checkin.id) == checkin
  #   end

  #   test "create_checkin/1 with valid data creates a checkin" do
  #     valid_attrs = %{
  #       status: :draft,
  #       origin: :local,
  #       source: "some source",
  #       uri: "some uri",
  #       content_html: "some content_html",
  #       visibility: :private,
  #       published_at: ~U[2025-04-23 12:17:00.000000Z]
  #     }

  #     assert {:ok, %Checkin{} = checkin} = Checkins.create_checkin(valid_attrs)
  #     assert checkin.status == :draft
  #     assert checkin.origin == :local
  #     assert checkin.source == "some source"
  #     assert checkin.uri == "some uri"
  #     assert checkin.content_html == "some content_html"
  #     assert checkin.visibility == :private
  #     assert checkin.published_at == ~U[2025-04-23 12:17:00.000000Z]
  #   end

  #   test "create_checkin/1 with invalid data returns error changeset" do
  #     assert {:error, %Ecto.Changeset{}} = Checkins.create_checkin(@invalid_attrs)
  #   end

  #   test "update_checkin/2 with valid data updates the checkin" do
  #     checkin = checkin_fixture()

  #     update_attrs = %{
  #       status: :published,
  #       origin: :remote,
  #       source: "some updated source",
  #       uri: "some updated uri",
  #       content_html: "some updated content_html",
  #       visibility: :unlisted,
  #       published_at: ~U[2025-04-24 12:17:00.000000Z]
  #     }

  #     assert {:ok, %Checkin{} = checkin} = Checkins.update_checkin(checkin, update_attrs)
  #     assert checkin.status == :published
  #     assert checkin.origin == :remote
  #     assert checkin.source == "some updated source"
  #     assert checkin.uri == "some updated uri"
  #     assert checkin.content_html == "some updated content_html"
  #     assert checkin.visibility == :unlisted
  #     assert checkin.published_at == ~U[2025-04-24 12:17:00.000000Z]
  #   end

  #   test "update_checkin/2 with invalid data returns error changeset" do
  #     checkin = checkin_fixture()
  #     assert {:error, %Ecto.Changeset{}} = Checkins.update_checkin(checkin, @invalid_attrs)
  #     assert checkin == Checkins.get_checkin!(checkin.id)
  #   end

  #   test "delete_checkin/1 deletes the checkin" do
  #     checkin = checkin_fixture()
  #     assert {:ok, %Checkin{}} = Checkins.delete_checkin(checkin)
  #     assert_raise Ecto.NoResultsError, fn -> Checkins.get_checkin!(checkin.id) end
  #   end

  #   test "change_checkin/1 returns a checkin changeset" do
  #     checkin = checkin_fixture()
  #     assert %Ecto.Changeset{} = Checkins.change_checkin(checkin)
  #   end
  # end
end
