defmodule Klaxon.Profiles.Profile do
  use Klaxon.Schema

  schema "profiles" do
    field :display_name, :string
    field :name, :string
    field :uri, :string
    field :inbox, :string
    field :private_key, :string, redact: true
    field :public_key, :string
    field :summary, :string

    has_many :principals, Klaxon.Profiles.Principal

    timestamps()
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :uri, :display_name, :summary, :inbox, :public_key, :private_key])
    |> validate_required([:name, :uri])
    |> unique_constraint(:uri)
  end

  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :uri, :display_name, :summary, :inbox, :public_key, :private_key])
    |> validate_required([:name, :uri])
  end

  def update_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:display_name, :summary, :inbox, :public_key, :private_key])
  end

  def uri_query(uri) do
    from p in __MODULE__, where: p.uri == ^uri
  end
end
