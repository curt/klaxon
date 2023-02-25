defmodule Klaxon.Profiles.Profile do
  use Ecto.Schema
  alias Klaxon.Profiles.Profile
  import Ecto.Query
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  @foreign_key_type EctoBase58
  schema "profiles" do
    field :display_name, :string
    field :name, :string
    field :uri, :string
    field :private_key, :string, redact: true
    field :public_key, :string
    field :summary, :string

    has_many :principals, Klaxon.Profiles.Principal

    timestamps()
  end

  # def changeset(profile, attrs) do
  #   profile
  #   |> cast(attrs, [:name, :display_name, :summary, :public_key, :private_key])
  #   |> validate_required([:name, :uri])
  # end

  def insert_changeset(attrs) do
    %Profile{}
    |> cast(attrs, [:name, :uri, :display_name, :summary, :public_key, :private_key])
    |> validate_required([:name, :uri])
  end

  def update_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:display_name, :summary, :public_key, :private_key])
  end

  def uri_query(uri) do
    from p in Profile, where: p.uri == ^uri
  end
end
