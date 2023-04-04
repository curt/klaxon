defmodule Klaxon.WebfingerTest do
  use Klaxon.DataCase

  alias Klaxon.Auth.User
  alias Klaxon.Profiles.Profile
  alias Klaxon.Webfinger

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

  describe "get_webfinger" do
    test "returns profile and resource if profile exists", %{profile: profile} do
      assert {:ok, {%Profile{}, _}} = Webfinger.get_webfinger(profile.uri, "acct:alice@localhost")
    end

    test "returns not found profile if profile does not exist", %{profile: profile} do
      assert {:error, :not_found} = Webfinger.get_webfinger(profile.uri, "acct:bob@localhost")
    end
  end
end
