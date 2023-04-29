defmodule Klaxon.Traces.Track do
  use Klaxon.Schema

  schema "tracks" do
    field :name, :string

    belongs_to :trace, Klaxon.Traces.Trace, type: EctoBase58
    has_many :segments, Klaxon.Traces.Segment

    timestamps()
  end

  @doc false
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:trace_id, :name])
  end
end
