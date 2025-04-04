defmodule Klaxon.Traces.Waypoint do
  use Klaxon.Schema

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          time: DateTime.t(),
          lat: float(),
          lon: float(),
          ele: float(),
          trace_id: integer(),
          trace: Klaxon.Traces.Trace.t()
        }

  @derive {Jason.Encoder,
           only: [
             :name,
             :time,
             :lat,
             :lon,
             :ele
           ]}

  schema "waypoints" do
    field :name, :string
    field :time, :utc_datetime_usec
    field :lat, :float
    field :lon, :float
    field :ele, :float

    belongs_to :trace, Klaxon.Traces.Trace, type: EctoBase58
  end

  @doc false
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:trace_id, :name, :time, :lat, :lon, :ele])
  end
end
