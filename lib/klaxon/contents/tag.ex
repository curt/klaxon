defmodule Klaxon.Contents.Tag do
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  @foreign_key_type EctoBase58
  schema "tags" do
    belongs_to :post, Klaxon.Contents.Post, type: EctoBase58
    belongs_to :label, Klaxon.Contents.Label, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [])
    |> validate_required([])
  end
end
