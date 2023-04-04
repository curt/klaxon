defmodule KlaxonWeb.WebfingerControllerTest do
  use KlaxonWeb.ConnCase, async: true

  alias Klaxon.Repo
  alias Klaxon.Auth.User
  alias Klaxon.Profiles.Profile

  describe "webfinger controller" do
    setup do
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
          name: "alice"
        })

      %{profile: profile}
    end

    test "show with hostname", %{conn: conn, profile: profile} do
      host = URI.new!(profile.uri).host

      conn =
        get(
          conn,
          Routes.webfinger_path(conn, :show, resource: "acct:#{profile.name}@#{host}")
        )

      assert json_response(conn, 200)
    end

    test "show without hostname", %{conn: conn, profile: profile} do
      conn = get(conn, Routes.webfinger_path(conn, :show, resource: "acct:#{profile.name}"))
      assert json_response(conn, 200)
    end

    test "show with incorrect hostname", %{conn: conn, profile: profile} do
      conn =
        get(conn, Routes.webfinger_path(conn, :show, resource: "acct:#{profile.name}@bad-example.com"))

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
end
