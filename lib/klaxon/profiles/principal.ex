defmodule Klaxon.Profiles.Principal do
  alias Klaxon.Profiles.Principal
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  schema "principals" do

    belongs_to :user, Klaxon.Auth.User, type: :binary_id
    belongs_to :profile, Klaxon.Profiles.Profile, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(principal, attrs) do
    principal
    |> cast(attrs, [])
    |> validate_required([])
  end

  def profile_query(profile) do
    from p in Principal, where: p.profile_id == ^profile.id
  end
end
