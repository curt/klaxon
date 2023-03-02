defmodule KlaxonWeb.WebfingerControllerTest do
  use KlaxonWeb.ConnCase

  import Klaxon.ProfileFixtures
  import Klaxon.AuthFixtures

  describe "webfinger controller" do
    setup [:create_profile]

    test "show", %{conn: conn, profile: profile} do
      conn = get(conn, Routes.webfinger_path(conn, :show, resource: "acct:#{profile.name}"))
      assert json_response(conn, 200)
    end
  end

  defp create_profile(%{conn: conn}) do
    user = user_fixture()
    # FIXME: Replace hard-coded profile URI with one that works.
    profile = profile_fixture(%{}, "http://www.example.com/", user)
    %{profile: profile, conn: conn, user: user}
  end
end
