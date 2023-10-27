defmodule Klaxon.Activities.Follow do
  use Klaxon.Schema

  schema "follows" do
    field :uri, :string
    field :follower_uri, :string
    field :followee_uri, :string
    field :status, Ecto.Enum, values: [:requested, :accepted, :rejected, :undone]

    timestamps()
  end

  @doc false
  def changeset(follow, attrs, endpoint) do
    follow
    |> cast(attrs, [:uri, :follower_uri, :followee_uri, :status])
    |> validate_required([:follower_uri, :followee_uri, :status])
    |> apply_tag(endpoint, :uri, "follow")
    |> unique_constraint(:uri)
  end
end
