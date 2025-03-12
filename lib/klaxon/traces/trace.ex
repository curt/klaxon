defmodule Klaxon.Traces.Trace do
  use Klaxon.Schema

  schema "traces" do
    field :name, :string
    field :created_at, :utc_datetime_usec, virtual: true

    belongs_to :profile, Klaxon.Profiles.Profile
    has_many :tracks, Klaxon.Traces.Track
    has_many :waypoints, Klaxon.Traces.Waypoint, preload_order: [:created_at]

    timestamps()
  end

  @doc false
  def changeset(trace, attrs \\ %{}) do
    trace
    |> cast(attrs, [:name, :profile_id])
  end
end
