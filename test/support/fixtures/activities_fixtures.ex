defmodule Klaxon.ActivitiesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Klaxon.Activities` context.
  """

  @doc """
  Generate a unique follow uri.
  """
  def unique_follow_uri, do: "some uri#{System.unique_integer([:positive])}"

  @doc """
  Generate a follow.
  """
  def follow_fixture(attrs \\ %{}) do
    {:ok, follow} =
      attrs
      |> Enum.into(%{
        status: :requested,
        uri: unique_follow_uri(),
        follower_uri: "https://example.com/actor/joe",
        followee_uri: "http://localhost:4002/"
      })
      |> Klaxon.Activities.create_follow("http://localhost:4002/")

    follow
  end
end
