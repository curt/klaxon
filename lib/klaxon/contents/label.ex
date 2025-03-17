defmodule Klaxon.Contents.Label do
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  @foreign_key_type EctoBase58
  schema "labels" do
    field :normalized, :string
    field :slug, :string
    field :title, :string

    has_many :tags, Klaxon.Contents.PostTag

    timestamps()
  end

  @doc false
  def changeset(label, attrs) do
    label
    |> cast(attrs, [:title, :normalized, :slug])
    |> validate_required([:title, :normalized, :slug])
    |> unique_constraint(:slug)
    |> unique_constraint(:normalized)
  end
end
