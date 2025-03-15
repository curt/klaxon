defmodule Klaxon.Traces.Trace do
  use Klaxon.Schema

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          created_at: DateTime.t() | nil,
          profile_id: integer() | nil,
          # FIXME: Klaxon.Profiles.Profile.t()
          profile: struct() | nil,
          tracks: [Klaxon.Traces.Track.t()],
          waypoints: [Klaxon.Traces.Waypoint.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "traces" do
    field :name, :string
    field :created_at, :utc_datetime_usec, virtual: true

    belongs_to :profile, Klaxon.Profiles.Profile
    has_many :tracks, Klaxon.Traces.Track
    has_many :waypoints, Klaxon.Traces.Waypoint, preload_order: [:created_at]

    timestamps()
  end

  @doc false
  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(trace, attrs \\ %{}) do
    trace
    |> cast(attrs, [:name, :profile_id])
  end
end
