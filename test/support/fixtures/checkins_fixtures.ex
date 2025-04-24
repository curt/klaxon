defmodule Klaxon.CheckinsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Klaxon.Checkins` context.
  """

  @doc """
  Generate a checkin.
  """
  def checkin_fixture(attrs \\ %{}) do
    {:ok, checkin} =
      attrs
      |> Enum.into(%{
        status: :draft,
        origin: :local,
        source: "some source",
        uri: "some uri",
        content_html: "some content_html",
        visibility: :private,
        published_at: ~U[2025-04-23 12:17:00.000000Z]
      })
      |> Klaxon.Checkins.create_checkin()

    checkin
  end
end
