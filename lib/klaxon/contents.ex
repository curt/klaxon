defmodule Klaxon.Contents do
  @moduledoc """
  Interactions between `Klaxon.Contents` schemas and repo.
  """
  require Logger
  alias Klaxon.HttpClient
  alias Klaxon.Repo
  alias Klaxon.Auth.User
  alias Klaxon.Profiles
  alias Klaxon.Contents.Post
  import Ecto.Query

  # get_posts thoughts
  # - order by
  # - limit for unauthenticated
  # - option to include remote posts

  @doc """
  Gets posts from repo for given endpoint and user (if specified).
  """
  @spec get_posts(String.t(), %Klaxon.Auth.User{id: String.t()} | nil) ::
          {:error, :not_found} | {:ok, maybe_improper_list}
  def get_posts(endpoint, %User{id: user_id} = _user) do
    get_posts_authenticated(endpoint, user_id)
  end

  def get_posts(endpoint, _) do
    get_posts_unauthenticated(endpoint)
  end

  @doc """
  Gets post from repo for given endpoint, identifier, and user (if specified).
  """
  @spec get_post(String.t(), String.t(), %Klaxon.Auth.User{id: String.t()} | nil) ::
          {:error, :not_found} | {:ok, %Klaxon.Contents.Post{id: String.t()}}
  def get_post(endpoint, post_id, %User{id: user_id} = _user) do
    get_post_authenticated(endpoint, post_id, user_id)
  end

  def get_post(endpoint, post_id, _) do
    get_post_unauthenticated(endpoint, post_id)
  end

  defp get_posts_authenticated(endpoint, user_id) do
    if is_user_id_endpoint_principal?(endpoint, user_id) do
      get_posts_authorized(endpoint)
    else
      get_posts_unauthenticated(endpoint)
    end
  end

  defp get_posts_authorized(endpoint) do
    case Post.from_preloaded()
         |> where_authorized(endpoint)
         |> Repo.all() do
      posts when is_list(posts) -> {:ok, posts}
      _ -> {:error, :not_found}
    end
  end

  defp get_posts_unauthenticated(endpoint) do
    case Post.from_preloaded()
         |> where_unauthenticated(endpoint)
         |> Repo.all() do
      posts when is_list(posts) -> {:ok, posts}
      _ -> {:error, :not_found}
    end
  end

  defp get_post_authenticated(endpoint, post_id, user_id) do
    if is_user_id_endpoint_principal?(endpoint, user_id) do
      get_post_authorized(endpoint, post_id)
    else
      get_post_unauthenticated(endpoint, post_id)
    end
  end

  defp get_post_authorized(endpoint, post_id) do
    case Post.from_preloaded()
         |> where_authorized(endpoint)
         |> Post.where_post_id(post_id)
         |> Repo.one() do
      %Post{} = post -> {:ok, post}
      _ -> {:error, :not_found}
    end
  end

  defp get_post_unauthenticated(endpoint, post_id) do
    case Post.from_preloaded()
         |> where_unauthenticated(endpoint)
         |> Post.where_post_id(post_id)
         |> Repo.one() do
      %Post{} = post -> {:ok, post}
      _ -> {:error, :not_found}
    end
  end

  defp where_authorized(query, endpoint) do
    query
    |> Post.where_origin([:local, :remote])
    |> Post.where_status([:published, :draft])
    |> Post.where_visibility([:public, :unlisted, :private])
    # TODO: refactor next line into Post module
    |> where(
      [posts: p, profile: r],
      p.origin == :remote or (p.status == :published and p.visibility == :public) or
        r.uri == ^endpoint
    )
  end

  defp where_unauthenticated(query, endpoint) do
    query
    |> Post.where_profile_uri(endpoint)
    |> Post.where_origin([:local])
    |> Post.where_status([:published])
    |> Post.where_visibility([:public])
  end

  defp is_user_id_endpoint_principal?(endpoint, user_id) do
    case Profiles.get_profile_by_uri(endpoint) do
      {:ok, profile} -> Enum.any?(profile.principals, fn x -> x.user_id == user_id end)
      _ -> false
    end
  end

  @spec get_or_fetch_public_post_by_uri(binary) :: %Post{} | nil
  def get_or_fetch_public_post_by_uri(profile_uri) do
    Repo.one(Post.uri_query(profile_uri)) ||
      fetch_public_post_by_uri(profile_uri)
  end

  @spec fetch_public_post_by_uri(binary) :: %Post{} | nil
  def fetch_public_post_by_uri(profile_uri) do
    case HttpClient.activity_get(profile_uri) do
      {:ok, %{body: body}} -> new_public_post_from_response(body)
      _ -> nil
    end
  end

  @spec new_public_post_from_response(map) :: %Post{} | nil
  def new_public_post_from_response(%{"id" => uri} = body) do
    profile_id = Map.get(body, "attributedTo")
    content_html = Map.get(body, "content")
    # TODO: Fake a tag if missing
    context_uri = Map.get(body, "conversation") || Map.get(body, "context")
    in_reply_to_uri = Map.get(body, "inReplyTo")

    # TODO: Missing published_at
    %Post{
      uri: uri,
      profile_id: profile_id,
      origin: :remote,
      status: :published,
      visibility: :unlisted,
      content_html: content_html,
      context_uri: context_uri,
      in_reply_to_uri: in_reply_to_uri
    }
  end

  def new_public_post_from_response(_body) do
    Logger.info("public post does not have required attributes")
    nil
  end
end
