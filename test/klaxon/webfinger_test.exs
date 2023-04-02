defmodule Klaxon.WebfingerTest do
  use Klaxon.DataCase

  import Klaxon.AuthFixtures
  import Klaxon.ProfileFixtures

  alias Klaxon.Profiles.Profile
  alias Klaxon.Webfinger

  setup do
    user = user_fixture()
    profile = profile_fixture(user)
    %{user: user, profile: profile}
  end

  describe "get_webfinger" do
    test "returns profile and resource if profile exists", %{profile: profile} do
      assert {:ok, {%Profile{}, _}} = Webfinger.get_webfinger(profile, "acct:alice@www.example.com")
    end

    test "returns not found profile if profile does not exist", %{profile: profile} do
      assert {:error, :not_found} = Webfinger.get_webfinger(profile, "acct:bob@www.example.com")
    end
  end
end
