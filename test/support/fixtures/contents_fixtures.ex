defmodule Klaxon.ContentsFixtures do
  alias Klaxon.Contents

  def post_fixture(_attrs \\ %{}) do
    %Contents.Post{}
  end

  def place_fixture(profile, attrs \\ %{}) do
    valid =
      %{
        source: "foo",
        uri: "https://example.com/places/some-place",
        title: "some place",
        slug: "some-place",
        lat: 1.0,
        lon: 2.0,
        status: :published,
        visibility: :public
      }
      |> Map.merge(attrs)

    {:ok, place} =
      Contents.insert_place(profile, valid, fn x -> "https://example.com/places/#{x}" end)

    place
  end
end
