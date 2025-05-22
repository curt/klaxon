defmodule Klaxon.Activities.Like do
  use Klaxon.Schema
  alias Klaxon.Profiles.Profile

  schema "likes" do
    field :uri, :string
    field :actor_uri, :string
    field :object_uri, :string

    belongs_to :actor, Profile, foreign_key: :actor_uri, references: :uri, define_field: false

    timestamps(updated_at: false)
  end

  def changeset(follow, attrs, endpoint) do
    follow
    |> cast(attrs, [:uri, :actor_uri, :object_uri])
    |> validate_required([:actor_uri, :object_uri])
    |> apply_tag(endpoint, :uri, "like")
    |> unique_constraint(:uri)
  end
end
