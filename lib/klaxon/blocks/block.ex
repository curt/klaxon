defmodule Klaxon.Blocks.Block do
  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  @foreign_key_type EctoBase58
  schema "blocks" do
    field :reason, :string
    field :subject, :string
    field :type, Ecto.Enum, values: [:domain, :subdomain, :profile, :object, :context]

    belongs_to :profile, Klaxon.Profiles.Profile, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(block, attrs) do
    block
    |> cast(attrs, [:subject, :reason, :type])
    |> validate_required([:subject, :type])
  end
end
