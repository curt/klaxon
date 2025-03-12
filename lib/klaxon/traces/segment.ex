defmodule Klaxon.Traces.Segment do
  use Klaxon.Schema

  schema "segments" do
    belongs_to :track, Klaxon.Traces.Track, type: EctoBase58
    has_many :trackpoints, Klaxon.Traces.Trackpoint, preload_order: [:created_at]

    timestamps()
  end

  @doc false
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:track_id])
  end
end
