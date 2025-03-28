defmodule Klaxon.Traces.Trackpoint do
  use Klaxon.Schema

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          time: DateTime.t(),
          lat: float(),
          lon: float(),
          ele: float(),
          segment_id: integer(),
          segment: Klaxon.Traces.Segment.t()
        }

  @derive {Jason.Encoder,
           only: [
             :time,
             :lat,
             :lon,
             :ele
           ]}

  schema "trackpoints" do
    field :name, :string
    field :time, :utc_datetime_usec
    field :lat, :float
    field :lon, :float
    field :ele, :float

    belongs_to :segment, Klaxon.Traces.Segment, type: EctoBase58
  end

  @doc false
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:segment_id, :name, :time, :lat, :lon, :ele])
  end
end
