defmodule Klaxon.Contents.Post do
  @derive {Jason.Encoder,
           only: [
             :content_html,
             :context_uri,
             :ele,
             :in_reply_to_uri,
             :inserted_at,
             :lat,
             :location,
             :lon,
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
  alias Ecto.Changeset
  alias TagUri

  schema "posts" do
    field(:attributed_to, :string, virtual: true)
    field(:content_html, :string)
    field(:context_uri, :string)
    field(:in_reply_to_uri, :string)
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
    field(:location, :string)

    belongs_to(:profile, Klaxon.Profiles.Profile, type: EctoBase58)
    has_many(:tags, Klaxon.Contents.Tag)
    has_many(:attachments, Klaxon.Contents.Attachment, preload_order: [:inserted_at])

    has_one(:in_reply_to, __MODULE__, references: :in_reply_to_uri, foreign_key: :uri)
    has_many(:replies, __MODULE__, references: :uri, foreign_key: :in_reply_to_uri)
    has_many(:conversation, __MODULE__, references: :context_uri, foreign_key: :context_uri)

    timestamps()
  end

  @doc false
  def changeset(post, attrs, host) do
    post
    |> cast(attrs, [
      :content_html,
      :context_uri,
      :in_reply_to_uri,
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
      :ele,
      :location
    ])
    |> validate_required([:uri, :status, :visibility, :origin])
    |> unique_constraint(:uri)
    |> apply_context_uri(host)
    |> apply_content_html()
    |> apply_published_at()
  end

  @spec apply_context_uri(Changeset.t(), String.t()) :: Changeset.t()
  def apply_context_uri(changeset, host) do
    changeset
    |> apply_tag(host, :context_uri, "context")
  end

  def apply_content_html(changeset) do
    if source = get_change(changeset, :source) do
      put_change_content_html(changeset, source)
    end || changeset
  end

  def put_change_content_html(changeset, source) do
    force_change(
      changeset,
      :content_html,
      source
      |> Earmark.as_html!(compact_output: true)
    )
  end

  def apply_published_at(changeset) do
    published_at = get_field(changeset, :published_at)

    if get_change(changeset, :status) == :published && !published_at do
      put_change(changeset, :published_at, DateTime.utc_now())
    end || changeset
  end

  def from_named() do
    from(p in __MODULE__, as: :posts)
  end

  def from_preloaded() do
    from_named() |> preload_all()
  end

  @doc """
  Preloads all associations for posts in given query.
  Assumes given query uses a named binding of `posts`.

  ## Examples

      iex> alias Klaxon.Repo
      iex> alias Klaxon.Contents.Post
      iex> import Ecto.Query
      iex> Repo.all(Post.preload_all(from p in Post, as: :posts))

  """
  @spec preload_all(Ecto.Query.t()) :: Ecto.Query.t()
  def preload_all(query) do
    query
    |> join(:inner, [posts: p], r in assoc(p, :profile), as: :profile)
    |> preload([p, r],
      profile: r,
      tags: [:label],
      attachments: [:media]
      # FIXME
      # ,
      # traces: :traces
    )
  end

  # TODO: Rename this.
  def uri_query(post_uri) do
    from_named() |> where_post_uri(post_uri)
  end

  def where_post_id(query, post_id) do
    where(query, [posts: p], p.id == ^post_id)
  end

  def where_post_uri(query, post_uri) do
    where(query, [posts: p], p.uri == ^post_uri)
  end

  def where_status(query, statuses) do
    where(query, [posts: p], p.status in ^statuses)
  end

  def where_origin(query, origins) do
    where(query, [posts: p], p.origin in ^origins)
  end

  def where_visibility(query, visibilities) do
    where(query, [posts: p], p.visibility in ^visibilities)
  end

  def where_published_at(query) do
    where(query, [posts: p], not is_nil(p.published_at))
  end

  def where_profile_uri(query, profile_uri) do
    where(query, [profile: r], r.uri == ^profile_uri)
  end

  def order_by_default(query) do
    order_by(query, [posts: p], desc_nulls_last: p.published_at, desc: p.inserted_at)
  end
end
