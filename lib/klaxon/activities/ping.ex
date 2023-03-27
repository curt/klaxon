defmodule Klaxon.Activities.Ping do
  use Klaxon.Schema

  schema "pings" do
    field :actor_uri, :string
    field :direction, Ecto.Enum, values: [:in, :out]
    field :to_uri, :string
    field :uri, :string

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(ping, attrs, endpoint) do
    ping
    |> cast(attrs, [:uri, :direction, :actor_uri, :to_uri])
    |> validate_required([:direction, :actor_uri, :to_uri])
    |> apply_tag(endpoint, :uri, "ping")
  end
end
