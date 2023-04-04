defmodule KlaxonWeb.ProfileControllerTest do
  use KlaxonWeb.ConnCase

  alias Klaxon.Repo
  alias Klaxon.Auth.User
  alias Klaxon.Profiles.Profile

  @update_attrs %{display_name: "some updated display_name", summary: "some updated summary"}
  # TODO: Will be needed when profile attributes are extended.
  # @invalid_attrs %{display_name: nil, summary: nil}

  describe "index with no profile" do
    test "display profile", %{conn: conn} do
      conn = %Plug.Conn{conn | host: "sample.org"}
      conn = get(conn, Routes.profile_path(conn, :index))
      assert html_response(conn, 503) =~ "no profile"
    end
  end

  describe "index with activity+json" do
    setup [:create_profile, :activity_json]

    test "get profile", %{conn: conn} do
      conn = get(conn, Routes.profile_path(conn, :index))
      json_response(conn, 200)
    end
  end

  describe "index" do
    setup [:create_profile]

    test "display profile", %{conn: conn, profile: profile} do
      conn = get(conn, Routes.profile_path(conn, :index))
      assert html_response(conn, 200) =~ profile.display_name
    end
  end

  describe "edit profile" do
    setup [:create_profile, :log_in_user]

    test "renders form for editing chosen profile", %{conn: conn, profile: profile} do
      conn = get(conn, Routes.profile_path(conn, :edit))
      assert html_response(conn, 200) =~ profile.display_name
    end
  end

  describe "update profile" do
    setup [:create_profile, :log_in_user]

    test "redirects when data is valid", %{conn: conn} do
      conn = put(conn, Routes.profile_path(conn, :update), profile: @update_attrs)
      assert redirected_to(conn) == Routes.profile_path(conn, :index)

      conn = get(conn, Routes.profile_path(conn, :index))
      assert html_response(conn, 200) =~ "some updated display_name"
    end

    # TODO: Will be needed when profile attributes are extended.
    # test "renders errors when data is invalid", %{conn: conn, profile: profile} do
    #   conn = put(conn, Routes.profile_path(conn, :update), profile: @invalid_attrs)
    #   assert html_response(conn, 200) =~ profile.display_name
    # end
  end

  defp create_profile(_) do
    user =
      Repo.insert!(%User{
        email: "alice@example.com",
        hashed_password: "password"
      })

    profile =
      Repo.insert!(%Profile{
        owner_id: user.id,
        # NOTE! The host and port need to reflect the controller conn.
        uri: "http://localhost:4002/",
        name: "alice",
        display_name: "Alice N. Wonderland"
      })

    %{user: user, profile: profile}
  end

  defp activity_json(_) do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("accept", "application/activity+json")

    %{conn: conn}
  end
end
