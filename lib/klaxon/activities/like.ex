defmodule Klaxon.Activities.Like do
  use Klaxon.Schema

  schema "likes" do
    field :uri, :string
    field :actor_uri, :string
    field :object_uri, :string

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
