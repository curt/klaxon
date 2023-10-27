defmodule Klaxon.ActivitiesTest do
  use Klaxon.DataCase

  alias Klaxon.Activities

  describe "follows" do
    alias Klaxon.Activities.Follow

    import Klaxon.ActivitiesFixtures

    @invalid_attrs %{status: nil, uri: nil, follower_uri: nil, followee_uri: nil}

    test "list_follows/0 returns all follows" do
      follow = follow_fixture()
      assert Activities.list_follows() == [follow]
    end

    test "get_follow!/1 returns the follow with given id" do
      follow = follow_fixture()
      assert Activities.get_follow!(follow.id) == follow
    end

    test "create_follow/1 with valid data creates a follow" do
      valid_attrs = %{
        status: :requested,
        uri: "some uri",
        follower_uri: "some follower_uri",
        followee_uri: "some followee_uri"
      }

      assert {:ok, %Follow{} = follow} =
               Activities.create_follow(valid_attrs, "http://localhost:4002/")

      assert follow.status == :requested
      assert follow.uri == "some uri"
      assert follow.follower_uri == "some follower_uri"
      assert follow.followee_uri == "some followee_uri"
    end

    test "create_follow/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Activities.create_follow(@invalid_attrs, "http://localhost:4002/")
    end

    test "update_follow/2 with valid data updates the follow" do
      follow = follow_fixture()

      update_attrs = %{
        status: :accepted,
        uri: "some updated uri",
        follower_uri: "some updated follower_uri",
        followee_uri: "some updated followee_uri"
      }

      assert {:ok, %Follow{} = follow} =
               Activities.update_follow(follow, update_attrs, "http://localhost:4002/")

      assert follow.status == :accepted
      assert follow.uri == "some updated uri"
      assert follow.follower_uri == "some updated follower_uri"
      assert follow.followee_uri == "some updated followee_uri"
    end

    test "update_follow/2 with invalid data returns error changeset" do
      follow = follow_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Activities.update_follow(follow, @invalid_attrs, "http://localhost:4002/")

      assert follow == Activities.get_follow!(follow.id)
    end

    test "delete_follow/1 deletes the follow" do
      follow = follow_fixture()
      assert {:ok, %Follow{}} = Activities.delete_follow(follow)
      assert_raise Ecto.NoResultsError, fn -> Activities.get_follow!(follow.id) end
    end

    test "change_follow/1 returns a follow changeset" do
      follow = follow_fixture()
      assert %Ecto.Changeset{} = Activities.change_follow(follow, %{}, "http://localhost:4002/")
    end

    test "receive follow with valid data, with uri" do
      uri = unique_follow_uri()

      assert {:ok, %Follow{} = follow} =
               Activities.receive_follow(
                 uri,
                 "some follower_uri",
                 "some followee_uri",
                 "http://localhost:4002/"
               )

      assert follow.status == :requested
      assert follow.uri == uri
    end

    test "receive follow with valid data, without uri" do
      assert {:ok, %Follow{} = follow} =
               Activities.receive_follow(
                 nil,
                 "some follower_uri",
                 "some followee_uri",
                 "http://localhost:4002/"
               )

      assert follow.status == :requested
      refute is_nil(follow.uri)
    end

    test "receive follow for an existing pair" do
      existing = follow_fixture()

      assert {:ok, %Follow{} = follow} =
               Activities.receive_follow(
                 nil,
                 existing.follower_uri,
                 existing.followee_uri,
                 "http://localhost:4002/"
               )

      assert follow.status == :requested
    end

    test "receive undo follow, with uri" do
      follow = follow_fixture()

      assert {:ok, %Follow{} = updated} =
               Activities.receive_undo_follow(follow.uri, nil, nil, "http://localhost:4002/")

      assert updated.uri == follow.uri
      assert updated.status == :undone
    end

    test "receive undo follow, without uri" do
      follow = follow_fixture()

      assert {:ok, %Follow{} = updated} =
               Activities.receive_undo_follow(
                 nil,
                 follow.follower_uri,
                 follow.followee_uri,
                 "http://localhost:4002/"
               )

      assert updated.uri == follow.uri
      assert updated.status == :undone
    end
  end
end
