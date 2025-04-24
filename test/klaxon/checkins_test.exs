defmodule Klaxon.CheckinsTest do
  use Klaxon.DataCase

  alias Klaxon.Checkins

  describe "checkins" do
    alias Klaxon.Checkins.Checkin

    import Klaxon.CheckinsFixtures

    @invalid_attrs %{status: nil, origin: nil, source: nil, uri: nil, content_html: nil, visibility: nil, published_at: nil}

    test "list_checkins/0 returns all checkins" do
      checkin = checkin_fixture()
      assert Checkins.list_checkins() == [checkin]
    end

    test "get_checkin!/1 returns the checkin with given id" do
      checkin = checkin_fixture()
      assert Checkins.get_checkin!(checkin.id) == checkin
    end

    test "create_checkin/1 with valid data creates a checkin" do
      valid_attrs = %{status: :draft, origin: :local, source: "some source", uri: "some uri", content_html: "some content_html", visibility: :private, published_at: ~U[2025-04-23 12:17:00.000000Z]}

      assert {:ok, %Checkin{} = checkin} = Checkins.create_checkin(valid_attrs)
      assert checkin.status == :draft
      assert checkin.origin == :local
      assert checkin.source == "some source"
      assert checkin.uri == "some uri"
      assert checkin.content_html == "some content_html"
      assert checkin.visibility == :private
      assert checkin.published_at == ~U[2025-04-23 12:17:00.000000Z]
    end

    test "create_checkin/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Checkins.create_checkin(@invalid_attrs)
    end

    test "update_checkin/2 with valid data updates the checkin" do
      checkin = checkin_fixture()
      update_attrs = %{status: :published, origin: :remote, source: "some updated source", uri: "some updated uri", content_html: "some updated content_html", visibility: :unlisted, published_at: ~U[2025-04-24 12:17:00.000000Z]}

      assert {:ok, %Checkin{} = checkin} = Checkins.update_checkin(checkin, update_attrs)
      assert checkin.status == :published
      assert checkin.origin == :remote
      assert checkin.source == "some updated source"
      assert checkin.uri == "some updated uri"
      assert checkin.content_html == "some updated content_html"
      assert checkin.visibility == :unlisted
      assert checkin.published_at == ~U[2025-04-24 12:17:00.000000Z]
    end

    test "update_checkin/2 with invalid data returns error changeset" do
      checkin = checkin_fixture()
      assert {:error, %Ecto.Changeset{}} = Checkins.update_checkin(checkin, @invalid_attrs)
      assert checkin == Checkins.get_checkin!(checkin.id)
    end

    test "delete_checkin/1 deletes the checkin" do
      checkin = checkin_fixture()
      assert {:ok, %Checkin{}} = Checkins.delete_checkin(checkin)
      assert_raise Ecto.NoResultsError, fn -> Checkins.get_checkin!(checkin.id) end
    end

    test "change_checkin/1 returns a checkin changeset" do
      checkin = checkin_fixture()
      assert %Ecto.Changeset{} = Checkins.change_checkin(checkin)
    end
  end
end
