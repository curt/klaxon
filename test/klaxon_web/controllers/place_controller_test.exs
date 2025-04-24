defmodule KlaxonWeb.PlaceControllerTest do
  use KlaxonWeb.ConnCase, async: true
  import Klaxon.ContentsFixtures
  import Klaxon.ProfileFixtures

  alias Klaxon.Auth.User
  alias Klaxon.Repo

  setup %{conn: conn} do
    user =
      Repo.insert!(%User{
        email: "alice@example.com",
        hashed_password: "password"
      })

    profile = profile_fixture(user)
    conn = assign(conn, :current_profile, profile)
    {:ok, conn: conn, profile: profile}
  end

  test "lists all places", %{conn: conn, profile: profile} do
    place = place_fixture(profile)
    conn = get(conn, Routes.place_path(conn, :index))
    assert html_response(conn, 200) =~ place.title
  end

  test "shows a place", %{conn: conn, profile: profile} do
    place = place_fixture(profile)
    conn = get(conn, Routes.place_path(conn, :show, place))
    assert html_response(conn, 200) =~ place.title
  end

  test "creates a place, not signed in", %{conn: conn, profile: _profile} do
    place_params = %{title: "New Place", lat: 10.0, lon: 20.0}
    conn = post(conn, Routes.place_path(conn, :create), place: place_params)
    assert html_response(conn, 401)
  end

  test "updates a place, not signed in", %{conn: conn, profile: profile} do
    place = place_fixture(profile)
    conn = put(conn, Routes.place_path(conn, :update, place), place: %{title: "Updated"})
    assert html_response(conn, 401)
  end

  test "deletes a place, not signed in", %{conn: conn, profile: profile} do
    place = place_fixture(profile)
    conn = delete(conn, Routes.place_path(conn, :delete, place))
    assert html_response(conn, 401)
  end
end
