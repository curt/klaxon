defmodule KlaxonWeb.WebfingerControllerTest do
  use KlaxonWeb.ConnCase

  import Klaxon.ProfileFixtures
  import Klaxon.AuthFixtures

  describe "webfinger controller" do
    setup [:create_profile]

    test "show with hostname", %{conn: conn, profile: profile} do
      endpoint = URI.new!(profile.uri)
      conn = get(conn, Routes.webfinger_path(conn, :show, resource: "acct:#{profile.name}@#{endpoint.host}"))
      assert json_response(conn, 200)
    end

    test "show without hostname", %{conn: conn, profile: profile} do
      conn = get(conn, Routes.webfinger_path(conn, :show, resource: "acct:#{profile.name}"))
      assert json_response(conn, 200)
    end

    test "show with incorrect hostname", %{conn: conn, profile: profile} do
      conn = get(conn, Routes.webfinger_path(conn, :show, resource: "acct:#{profile.name}@sample.com"))
      assert html_response(conn, 404)
    end

    test "show with incorrect name", %{conn: conn, profile: _profile} do
      conn = get(conn, Routes.webfinger_path(conn, :show, resource: "acct:bob"))
      assert html_response(conn, 404)
    end

    test "show with malformed resource, missing colon", %{conn: conn, profile: profile} do
      conn = get(conn, Routes.webfinger_path(conn, :show, resource: "acct=#{profile.name}"))
      assert html_response(conn, 400)
    end

    test "show with malformed resource, misspelled resource type", %{conn: conn, profile: profile} do
      conn = get(conn, Routes.webfinger_path(conn, :show, resource: "account:#{profile.name}"))
      assert html_response(conn, 400)
    end
  end

  defp create_profile(%{conn: conn}) do
    user = user_fixture()
    # FIXME: Replace hard-coded profile URI with one that works.
    profile = profile_fixture(user, %{})
    %{profile: profile, conn: conn, user: user}
  end
end
