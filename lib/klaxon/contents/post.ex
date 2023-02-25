defmodule Klaxon.Contents.Post do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  @foreign_key_type EctoBase58
  schema "posts" do
    field :content_html, :string
    field :context_uri, :string
    field :in_reply_to_uri, :string
    field :origin, Ecto.Enum, values: [:local, :remote], default: :remote
    field :published_at, :utc_datetime_usec
    field :slug, :string
    field :source, :string
    field :status, Ecto.Enum, values: [:draft, :published, :deleted], default: :draft
    field :title, :string
    field :uri, :string
    field :visibility, Ecto.Enum, values: [:private, :unlisted, :public], default: :public

    belongs_to :profile, Klaxon.Profiles.Profile, type: EctoBase58
    has_many :tags, Klaxon.Contents.Tag

    timestamps()
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :uri,
      :context_uri,
      :in_reply_to_uri,
      :slug,
      :source,
      :content_html,
      :title,
      :status,
      :visibility,
      :origin,
      :published_at
    ])
    |> validate_required([:uri, :context_uri, :status, :visibility, :origin])
    |> unique_constraint(:uri)
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
    |> join(:left, [posts: p], r in assoc(p, :profile), as: :profile)
    |> join(:left, [posts: p], t in assoc(p, :tags), as: :tags)
    |> join(:left, [tags: t], l in assoc(t, :label), as: :labels)
    |> preload([profile: r, tags: t, labels: l], profile: r, tags: {t, label: l})
  end

  def where_post_id(query, post_id) do
    where(query, [posts: p], p.id == ^post_id)
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

  def where_profile_uri(query, profile_uri) do
    where(query, [profile: r], r.uri == ^profile_uri)
  end
end
