defmodule Klaxon.Profiles.Profile do
  use Klaxon.Schema

  schema "profiles" do
    field :display_name, :string
    field :icon_media_type, :string
    field :icon, :string
    field :image_media_type, :string
    field :image, :string
    field :inbox, :string
    field :name, :string
    field :private_key, :string, redact: true
    field :public_key_id, :string
    field :public_key, :string
    field :summary, :string
    field :uri, :string
    field :url, :string

    has_many :principals, Klaxon.Profiles.Principal

    timestamps()
  end

  @common_cast_attrs [
    :display_name,
    :icon_media_type,
    :icon,
    :image_media_type,
    :image,
    :inbox,
    :private_key,
    :public_key_id,
    :public_key,
    :summary,
    :url
  ]

  def changeset(profile, attrs) do
    (profile || %__MODULE__{})
    |> cast(attrs, [:name, :uri] ++ @common_cast_attrs)
    |> validate_required([:name, :uri])
    |> unique_constraint(:uri)
  end

  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :uri] ++ @common_cast_attrs)
    |> validate_required([:name, :uri])
  end

  def update_changeset(profile, attrs) do
    profile
    |> cast(attrs, @common_cast_attrs)
  end

  @spec uri_query(binary) :: Ecto.Query.t()
  def uri_query(uri) do
    from p in __MODULE__, where: p.uri == ^uri
  end

  @spec where_fresh(Ecto.Query.t(), integer) :: Ecto.Query.t()
  def where_fresh(query, seconds) do
    cutoff = DateTime.add(DateTime.utc_now(), seconds)
    where(query, [p], p.updated_at >= ^cutoff)
  end
end
