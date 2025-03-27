defmodule Klaxon.Traces.Segment do
  use Klaxon.Schema

  @type t :: %__MODULE__{
          id: integer(),
          track_id: integer(),
          track: Klaxon.Traces.Track.t(),
          trackpoints: [Klaxon.Traces.Trackpoint.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @derive {Jason.Encoder,
           only: [
             :trackpoints
           ]}

  schema "segments" do
    belongs_to :track, Klaxon.Traces.Track, type: EctoBase58
    has_many :trackpoints, Klaxon.Traces.Trackpoint, preload_order: [:time]

    timestamps()
  end

  @doc false
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:track_id])
  end
end
