defmodule Klaxon.Traces.Trace do
  use Klaxon.Schema

  schema "traces" do
    field :name, :string

    belongs_to :post, Klaxon.Contents.Post, type: EctoBase58
    has_many :tracks, Klaxon.Traces.Track
    has_many :waypoints, Klaxon.Traces.Waypoint

    timestamps()
  end

  @doc false
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:name, :post_id])
  end
end
