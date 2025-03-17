defmodule Klaxon.Contents.Place do
  @moduledoc """
  Defines a Place schema and associated functions.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          content_html: String.t() | nil,
          origin: :local | :remote,
          published_at: DateTime.t() | nil,
          slug: String.t() | nil,
          source: String.t() | nil,
          status: :draft | :published | :deleted,
          title: String.t(),
          uri: String.t(),
          visibility: :private | :unlisted | :public,
          lat: float(),
          lon: float(),
          ele: float() | nil,
          profile_id: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @derive {Jason.Encoder,
           only: [
             :id,
             :content_html,
             :inserted_at,
             :lat,
             :lon,
             :ele,
             :origin,
             :profile_id,
             :published_at,
             :slug,
             :source,
             :status,
             :title,
             :updated_at,
             :uri,
             :visibility
           ]}

  use Klaxon.Schema
  import Klaxon.Contents.Helpers

  schema "places" do
    field(:content_html, :string)
    field(:origin, Ecto.Enum, values: [:local, :remote], default: :remote)
    field(:published_at, :utc_datetime_usec)
    field(:slug, :string)
    field(:source, :string)
    field(:status, Ecto.Enum, values: [:draft, :published, :deleted], default: :draft)
    field(:title, :string)
    field(:uri, :string)
    field(:visibility, Ecto.Enum, values: [:private, :unlisted, :public], default: :public)
    field(:lat, :float)
    field(:lon, :float)
    field(:ele, :float)

    belongs_to(:profile, Klaxon.Profiles.Profile, type: EctoBase58)
    has_many(:tags, Klaxon.Contents.PlaceTag)
    has_many(:attachments, Klaxon.Contents.PlaceAttachment)

    timestamps()
  end

  @doc false
  def changeset(place, attrs) do
    place
    |> cast(attrs, [
      :content_html,
      :origin,
      :profile_id,
      :published_at,
      :slug,
      :source,
      :status,
      :title,
      :uri,
      :visibility,
      :lat,
      :lon,
      :ele
    ])
    |> validate_required([:uri, :status, :visibility, :origin, :lat, :lon, :title])
    |> unique_constraint(:uri)
    |> apply_content_html()
    |> apply_published_at()
  end

  @doc """
  Returns a query for the `places` table.

  ## Examples

      iex> Klaxon.Contents.Place.from_named()
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places>

  """
  @spec from_named() :: Ecto.Query.t()
  def from_named() do
    from(p in __MODULE__, as: :places)
  end

  @doc """
  Returns a query for the `places` table with all associations preloaded.

  ## Examples

      iex> Klaxon.Contents.Place.from_preloaded()
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, preload: [:profile, :tags, :attachments]>

  """
  @spec from_preloaded() :: Ecto.Query.t()
  def from_preloaded() do
    from_named() |> preload_all()
  end

  @doc """
  Preloads all associations for places in the given query.
  Assumes the given query uses a named binding of `places`.

  ## Examples

      iex> alias Klaxon.Repo
      iex> alias Klaxon.Contents.Place
      iex> import Ecto.Query
      iex> Repo.all(Place.preload_all(from p in Place, as: :places))

  """
  @spec preload_all(Ecto.Query.t()) :: Ecto.Query.t()
  def preload_all(query) do
    query
    |> join(:inner, [places: p], r in assoc(p, :profile), as: :profile)
    |> preload([p, r],
      profile: r,
      tags: [:label],
      attachments: [:media]
    )
  end

  @doc """
  Returns a query for the `places` table filtered by the given URI.

  ## Examples

      iex> Klaxon.Contents.Place.uri_query("some-uri")
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, where: p.uri == ^"some-uri">

  """
  @spec uri_query(String.t()) :: Ecto.Query.t()
  def uri_query(place_uri) do
    from_named() |> where_place_uri(place_uri)
  end

  @doc """
  Returns a query for the `places` table filtered by the given place ID.

  ## Examples

      iex> Klaxon.Contents.Place.where_place_id(query, 1)
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, where: p.id == ^1>

  """
  @spec where_place_id(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_place_id(query, place_id) do
    where(query, [places: p], p.id == ^place_id)
  end

  @doc """
  Returns a query for the `places` table filtered by the given URI.

  ## Examples

      iex> Klaxon.Contents.Place.where_place_uri(query, "some-uri")
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, where: p.uri == ^"some-uri">

  """
  @spec where_place_uri(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_place_uri(query, place_uri) do
    where(query, [places: p], p.uri == ^place_uri)
  end

  @doc """
  Returns a query for the `places` table filtered by the given statuses.

  ## Examples

      iex> Klaxon.Contents.Place.where_status(query, [:draft, :published])
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, where: p.status in ^[:draft, :published]>

  """
  @spec where_status(Ecto.Query.t(), [atom()]) :: Ecto.Query.t()
  def where_status(query, statuses) do
    where(query, [places: p], p.status in ^statuses)
  end

  @doc """
  Returns a query for the `places` table filtered by the given origins.

  ## Examples

      iex> Klaxon.Contents.Place.where_origin(query, [:local, :remote])
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, where: p.origin in ^[:local, :remote]>

  """
  @spec where_origin(Ecto.Query.t(), [atom()]) :: Ecto.Query.t()
  def where_origin(query, origins) do
    where(query, [places: p], p.origin in ^origins)
  end

  @doc """
  Returns a query for the `places` table filtered by the given visibilities.

  ## Examples

      iex> Klaxon.Contents.Place.where_visibility(query, [:private, :public])
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, where: p.visibility in ^[:private, :public]>

  """
  @spec where_visibility(Ecto.Query.t(), [atom()]) :: Ecto.Query.t()
  def where_visibility(query, visibilities) do
    where(query, [places: p], p.visibility in ^visibilities)
  end

  @doc """
  Returns a query for the `places` table filtered by non-null published_at.

  ## Examples

      iex> Klaxon.Contents.Place.where_published_at(query)
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, where: not is_nil(p.published_at)>

  """
  @spec where_published_at(Ecto.Query.t()) :: Ecto.Query.t()
  def where_published_at(query) do
    where(query, [places: p], not is_nil(p.published_at))
  end

  @doc """
  Returns a query for the `places` table filtered by the given profile URI.

  ## Examples

      iex> Klaxon.Contents.Place.where_profile_uri(query, "profile-uri")
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, join: r in assoc(p, :profile), where: r.uri == ^"profile-uri">

  """
  @spec where_profile_uri(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def where_profile_uri(query, profile_uri) do
    where(query, [profile: r], r.uri == ^profile_uri)
  end

  @doc """
  Returns a query for the `places` table ordered by published_at and inserted_at.

  ## Examples

      iex> Klaxon.Contents.Place.order_by_default(query)
      #Ecto.Query<from p in Klaxon.Contents.Place, as: :places, order_by: [desc_nulls_last: p.published_at, desc: p.inserted_at]>

  """
  @spec order_by_default(Ecto.Query.t()) :: Ecto.Query.t()
  def order_by_default(query) do
    order_by(query, [places: p], desc_nulls_last: p.published_at, desc: p.inserted_at)
  end
end
