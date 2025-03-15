defmodule Klaxon.Traces.Track do
  use Klaxon.Schema

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          trace_id: integer(),
          trace: Klaxon.Traces.Trace.t(),
          segments: [Klaxon.Traces.Segment.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "tracks" do
    field :name, :string

    belongs_to :trace, Klaxon.Traces.Trace, type: EctoBase58
    has_many :segments, Klaxon.Traces.Segment

    timestamps()
  end

  @doc false
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(trace, attrs) do
    trace
    |> cast(attrs, [:trace_id, :name])
  end
end
