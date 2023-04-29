defmodule Klaxon.Traces.Trackpoint do
  use Klaxon.Schema

  schema "trackpoints" do
    field :name, :string
    field :created_at, :utc_datetime_usec
    field :lat, :float
    field :lon, :float
    field :ele, :float

    belongs_to :segment, Klaxon.Traces.Segment, type: EctoBase58
  end

  @doc false
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:segment_id, :name, :created_at, :lat, :lon, :ele])
  end
end
