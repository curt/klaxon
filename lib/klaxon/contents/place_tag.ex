defmodule Klaxon.Contents.PlaceTag do
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  @foreign_key_type EctoBase58
  schema "place_tags" do
    belongs_to :place, Klaxon.Contents.Place, type: EctoBase58
    belongs_to :label, Klaxon.Contents.Label, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(place_tag, attrs) do
    place_tag
    |> cast(attrs, [])
    |> validate_required([])
  end
end
