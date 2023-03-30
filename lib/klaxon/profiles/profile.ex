defmodule Klaxon.Profiles.Profile do
  use Klaxon.Schema

  @common_cast_attrs [
    :url,
    :display_name,
    :summary,
    :inbox,
    :private_key,
    :public_key,
    :public_key_id,
    :icon,
    :icon_media_type,
    :image,
    :image_media_type
  ]

  schema "profiles" do
    field :display_name, :string
    field :name, :string
    field :uri, :string
    field :url, :string
    field :inbox, :string
    field :private_key, :string, redact: true
    field :public_key, :string
    field :public_key_id, :string
    field :summary, :string
    field :icon, :string
    field :icon_media_type, :string
    field :image, :string
    field :image_media_type, :string

    has_many :principals, Klaxon.Profiles.Principal

    timestamps()
  end

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
