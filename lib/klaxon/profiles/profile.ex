defmodule Klaxon.Profiles.Profile do
  use Klaxon.Schema
  alias Klaxon.Auth.User

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
    field :site_tag, :string
    field :site_text, :string
    field :site_title, :string
    field :summary, :string
    field :uri, :string
    field :url, :string

    belongs_to :owner, User, type: :binary_id

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
    :site_tag,
    :site_text,
    :site_title,
    :summary,
    :url
  ]

  def insert_changeset(attrs) do
    %__MODULE__{}
    |> upsert_changeset(attrs)
  end

  def update_changeset(profile, attrs) do
    profile
    |> cast(attrs, @common_cast_attrs)
  end

  def upsert_changeset(profile, attrs) do
    (profile || %__MODULE__{})
    |> cast(attrs, [:name, :uri, :owner_id] ++ @common_cast_attrs)
    |> validate_required([:name, :uri])
    |> unique_constraint(:uri)
  end
end
