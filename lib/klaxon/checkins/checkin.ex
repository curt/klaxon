defmodule Klaxon.Checkins.Checkin do
  use Klaxon.Schema
  import Klaxon.Contents.Helpers
  import Ecto.Changeset

  @typedoc """
  A checkin represents a user's visit to a physical place.

  ## Fields

  - `id`: Unique identifier for the checkin
  - `checked_in_at`: DateTime when the user checked in at the place
  - `content_html`: HTML content associated with the checkin
  - `origin`: Whether the checkin is local or remote
  - `published_at`: DateTime when the checkin was published
  - `source`: Source content for the checkin
  - `status`: Status of the checkin (draft, published, or deleted)
  - `uri`: Unique URI identifier for the checkin
  - `visibility`: Visibility setting (private, unlisted, or public)
  - `profile_id`: ID of the profile that created the checkin
  - `place_id`: ID of the place where the checkin occurred
  - `inserted_at`: DateTime when the record was created
  - `updated_at`: DateTime when the record was last updated
  """
  @type t :: %__MODULE__{
          id: String.t(),
          checked_in_at: DateTime.t(),
          content_html: String.t() | nil,
          origin: :local | :remote,
          published_at: DateTime.t() | nil,
          source: String.t() | nil,
          status: :draft | :published | :deleted,
          uri: String.t(),
          visibility: :private | :unlisted | :public,
          profile_id: String.t(),
          place_id: String.t(),
          profile: any(),
          place: Klaxon.Contents.Place.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "checkins" do
    field :checked_in_at, :utc_datetime_usec
    field :content_html, :string
    field :origin, Ecto.Enum, values: [:local, :remote], default: :remote
    field :published_at, :utc_datetime_usec
    field :source, :string
    field :status, Ecto.Enum, values: [:draft, :published, :deleted], default: :draft
    field :uri, :string
    field :visibility, Ecto.Enum, values: [:private, :unlisted, :public], default: :public

    belongs_to(:profile, Klaxon.Profiles.Profile, type: EctoBase58)
    belongs_to(:place, Klaxon.Contents.Place, type: EctoBase58)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(checkin, attrs) do
    checkin
    |> cast(attrs, [
      :checked_in_at,
      :content_html,
      :origin,
      :published_at,
      :source,
      :status,
      :uri,
      :visibility,
      :profile_id,
      :place_id
    ])
    |> validate_required([:checked_in_at, :origin, :status, :uri, :visibility])
    |> unique_constraint(:uri)
    |> apply_published_at()
  end

  @spec from_named() :: Ecto.Query.t()
  def from_named() do
    from(c in __MODULE__, as: :checkins)
  end

  @spec from_preloaded() :: Ecto.Query.t()
  def from_preloaded() do
    from_named() |> preload_all()
  end

  @spec preload_all(Ecto.Query.t()) :: Ecto.Query.t()
  def preload_all(query) do
    query
    |> join(:inner, [checkins: c], r in assoc(c, :profile), as: :profile)
    |> join(:inner, [checkins: c], p in assoc(c, :place), as: :place)
    |> preload([c, r, p], profile: r, place: p)
  end

  @spec where_place_id(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_place_id(query, place_id) do
    where(query, [checkins: c], c.place_id == ^place_id)
  end

  @spec where_authorized(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_authorized(query, profile_uri) do
    query
    |> where_origin([:local, :remote])
    |> where_status([:published, :draft])
    |> where_visibility([:public, :unlisted, :private])
    |> where(
      [checkins: c, profile: r],
      c.origin == :remote or (c.status == :published and c.visibility == :public) or
        r.uri == ^profile_uri
    )
  end

  @spec where_public_list(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_public_list(query, profile_uri) do
    query
    |> where_local_published(profile_uri)
    |> where_visibility([:public])
  end

  @spec where_public_single(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_public_single(query, profile_uri) do
    query
    |> where_local_published(profile_uri)
    |> where_visibility([:public, :unlisted])
  end

  defp where_local_published(query, profile_uri) do
    query
    |> where_profile_uri(profile_uri)
    |> where_origin([:local])
    |> where_status([:published])
    |> where_published_at()
  end

  @spec where_id(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_id(query, id) do
    where(query, [checkins: c], c.id == ^id)
  end

  @spec where_profile_uri(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_profile_uri(query, profile_uri) do
    where(query, [profile: r], r.uri == ^profile_uri)
  end

  @spec where_published_at(Ecto.Query.t()) :: Ecto.Query.t()
  def where_published_at(query) do
    where(query, [checkins: c], not is_nil(c.published_at))
  end

  @spec where_status(Ecto.Query.t(), [atom()]) :: Ecto.Query.t()
  def where_status(query, statuses) do
    where(query, [checkins: c], c.status in ^statuses)
  end

  @spec where_origin(Ecto.Query.t(), [atom()]) :: Ecto.Query.t()
  def where_origin(query, origins) do
    where(query, [checkins: c], c.origin in ^origins)
  end

  @spec where_visibility(Ecto.Query.t(), [atom()]) :: Ecto.Query.t()
  def where_visibility(query, visibilities) do
    where(query, [checkins: c], c.visibility in ^visibilities)
  end

  @spec order_by_default(Ecto.Query.t()) :: Ecto.Query.t()
  def order_by_default(query) do
    order_by(query, [checkins: c], desc_nulls_last: c.published_at, desc: c.inserted_at)
  end
end
