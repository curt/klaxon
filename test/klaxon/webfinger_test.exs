defmodule Klaxon.WebfingerTest do
  use Klaxon.DataCase


  import Klaxon.AuthFixtures
  import Klaxon.ProfileFixtures

  alias Klaxon.Profiles.Profile
  alias Klaxon.Webfinger

  describe "get_webfinger" do
    test "returns profile and resource if profile exists" do
      {profile, _user} = create_profile()
      assert {:ok, {%Profile{}, _}} = Webfinger.get_webfinger(profile, "acct:alice@localhost")
    end

    test "returns not found profile if profile does not exist" do
      {profile, _user} = create_profile()
      assert {:error, :not_found} = Webfinger.get_webfinger(profile, "acct:bob@localhost")
    end
  end

  defp create_profile() do
    user = user_fixture()
    profile = profile_fixture(%{}, "http://localhost/", user)
    {profile, user}
  end
end
