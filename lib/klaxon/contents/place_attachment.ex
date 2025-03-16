defmodule Klaxon.Contents.PlaceAttachment do
  use Klaxon.Schema

  schema "place_attachments" do
    field :caption, :string

    belongs_to :place, Klaxon.Contents.Place, type: EctoBase58
    belongs_to :media, Klaxon.Media.Media, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(place_attachment, attrs \\ %{}) do
    place_attachment
    |> cast(attrs, [:caption])
    |> validate_required([:caption])
  end
end
