defmodule Klaxon.Traces.Waypoint do
  use Klaxon.Schema

  schema "waypoints" do
    field :name, :string
    field :created_at, :utc_datetime_usec
    field :lat, :float
    field :lon, :float
    field :ele, :float

    belongs_to :trace, Klaxon.Traces.Trace, type: EctoBase58
  end

  @doc false
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:trace_id, :name, :created_at, :lat, :lon, :ele])
  end
end
