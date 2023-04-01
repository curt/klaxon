defmodule KlaxonWeb.UserRegistrationControllerTest do
  use KlaxonWeb.ConnCase

  import Klaxon.AuthFixtures
  import Klaxon.ProfileFixtures

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.user_registration_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "Log in</a>"
      assert response =~ "Register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(Routes.user_registration_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /users/register" do
    setup [:create_profile]
    @tag :capture_log
    test "creates account and logs the user in", %{conn: conn, profile: profile} do
      email = unique_user_email()

      conn =
        post(conn, Routes.user_registration_path(conn, :create), %{
          "user" => valid_user_attributes(email: email)
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      # TODO: Make assertions more useful.
      # assert response =~ "Settings</a>"
      # assert response =~ "Log out</a>"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.user_registration_path(conn, :create), %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end

  defp create_profile(%{conn: conn}) do
    conn = Map.put(conn, :host, "example.com")
    user = user_fixture()
    # FIXME: Replace hard-coded profile URI with one that works.
    profile = profile_fixture(%{}, "http://example.com/", user)
    %{profile: profile, conn: conn, user: user}
  end
end
