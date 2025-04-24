defmodule KlaxonWeb.Api.PlaceControllerTest do
  use KlaxonWeb.ConnCase

  alias Klaxon.Contents.Place
  alias Klaxon.Profiles.Profile
  alias Klaxon.Repo
  alias EctoBase58

  setup %{conn: conn} do
    user = insert_user()
    profile = insert_profile(user)

    private = Map.get(conn, :private, %{}) |> Map.put(:phoenix_router_url, "http://example.com")

    conn =
      conn
      |> assign(:current_user, user)
      |> assign(:current_profile, profile)
      |> Map.put(:private, private)

    {:ok, conn: conn, user: user, profile: profile}
  end

  describe "index/2" do
    test "lists places for a profile", %{conn: conn, profile: profile} do
      place = insert_place(profile)
      conn = KlaxonWeb.Api.PlaceController.index(conn, %{})
      [%{"id" => place_id}] = json_response(conn, 200)
      assert place_id == place.id
    end
  end

  describe "show/2" do
    test "retrieves a specific place", %{conn: conn, profile: profile} do
      place = insert_place(profile)
      conn = KlaxonWeb.Api.PlaceController.show(conn, %{"id" => place.id})
      assert json_response(conn, 200)["id"] == place.id
    end

    test "returns 404 if place does not exist", %{conn: conn} do
      {:error, :not_found} = KlaxonWeb.Api.PlaceController.show(conn, %{"id" => "nonexistent"})
    end
  end

  describe "create/2" do
    test "creates a new place", %{conn: conn, profile: _profile} do
      place_params = %{
        title: "New Place",
        uri: "new-place",
        lat: 10.0,
        lon: 20.0,
        status: :published,
        visibility: :public,
        origin: :local
      }

      conn = KlaxonWeb.Api.PlaceController.create(conn, %{"place" => place_params})
      assert %{"id" => _} = json_response(conn, 201)
    end

    test "fails with invalid data", %{conn: conn} do
      assert {:error, %Ecto.Changeset{action: :insert}} =
               KlaxonWeb.Api.PlaceController.create(conn, %{"place" => %{}})
    end
  end

  describe "update/2" do
    test "updates an existing place", %{conn: conn, profile: profile} do
      place = insert_place(profile)

      conn =
        KlaxonWeb.Api.PlaceController.update(conn, %{
          "id" => place.id,
          "place" => %{title: "Updated Title"}
        })

      assert json_response(conn, 200)["title"] == "Updated Title"
    end

    test "returns 404 for non-existent place", %{conn: conn} do
      {:error, :not_found} =
        KlaxonWeb.Api.PlaceController.update(conn, %{
          "id" => "nonexistent",
          "place" => %{title: "Updated Title"}
        })
    end
  end

  describe "delete/2" do
    test "deletes an existing place", %{conn: conn, profile: profile} do
      place = insert_place(profile)
      conn = KlaxonWeb.Api.PlaceController.delete(conn, %{"id" => place.id})
      assert response(conn, 204)
    end

    test "returns 404 for non-existent place", %{conn: conn} do
      {:error, :not_found} = KlaxonWeb.Api.PlaceController.delete(conn, %{"id" => "nonexistent"})
    end
  end

  defp insert_user do
    %Klaxon.Auth.User{
      id: Ecto.UUID.generate(),
      email: "test@example.com",
      hashed_password: "hashedpassword"
    }
    |> Repo.insert!()
  end

  defp insert_profile(user) do
    %Profile{
      id: EctoBase58.generate(),
      uri: "test-profile",
      name: "Test Profile",
      owner_id: user.id
    }
    |> Repo.insert!()
  end

  defp insert_place(profile) do
    %Place{
      id: EctoBase58.generate(),
      title: "Test Place",
      uri: "test-uri",
      lat: 10.0,
      lon: 20.0,
      status: :published,
      visibility: :public,
      origin: :local,
      profile_id: profile.id
    }
    |> Repo.insert!()
  end
end
