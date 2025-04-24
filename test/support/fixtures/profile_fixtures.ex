defmodule Klaxon.ProfileFixtures do
  alias Klaxon.Profiles
  alias Klaxon.Profiles.Profile

  def valid_profile_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      uri: "http://localhost:4002/",
      display_name: "Alice Jones",
      name: "alice",
      origin: :local
    })
  end

  def profile_fixture(user, attrs \\ %{}) do
    {:ok, %Profile{} = profile} =
      attrs
      |> valid_profile_attributes()
      |> Profiles.create_local_profile(user.id)

    profile
  end
end
