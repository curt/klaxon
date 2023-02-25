defmodule Klaxon.ProfileFixtures do
  def valid_profile_attributes(attrs \\ %{}, endpoint) do
    Enum.into(attrs, %{
      uri: endpoint,
      display_name: "Alice Jones",
      name: "alice"
    })
  end

  def profile_fixture(attrs \\ %{}, endpoint, user) do
    {:ok, %{principal: _, profile: profile}} =
      attrs
      |> valid_profile_attributes(endpoint)
      |> Klaxon.Profiles.create_local_profile(user.id)

    profile
  end
end
