defmodule Klaxon.ProfileFixtures do
  def valid_profile_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      uri: "http://www.example.com/",
      display_name: "Alice Jones",
      name: "alice"
    })
  end

  def profile_fixture(user, attrs \\ %{}) do
    {:ok, %{principal: _, profile: profile}} =
      attrs
      |> valid_profile_attributes()
      |> Klaxon.Profiles.create_local_profile(user.id)

    profile
  end
end
