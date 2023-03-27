defmodule Klaxon.Activities.Pong do
  use Klaxon.Schema

  schema "pongs" do
    field :actor_uri, :string
    field :direction, Ecto.Enum, values: [:in, :out]
    field :object_uri, :string
    field :to_uri, :string
    field :uri, :string

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(pong, attrs, endpoint) do
    pong
    |> cast(attrs, [:uri, :direction, :actor_uri, :to_uri, :object_uri])
    |> validate_required([:direction, :actor_uri, :to_uri, :object_uri])
    |> apply_tag(endpoint, :uri, "pong")
  end
end
