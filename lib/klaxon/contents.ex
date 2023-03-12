defmodule Klaxon.Contents do
  @moduledoc """
  Interactions between `Klaxon.Contents` schemas and repo.
  """
  require Logger
  alias Klaxon.HttpClient
  alias Klaxon.Repo
  alias Klaxon.Auth.User
  alias Klaxon.Profiles
  alias Klaxon.Profiles.Profile
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

  @spec get_public_post_by_uri(binary) :: struct | nil
  def get_public_post_by_uri(post_uri) do
    Repo.one(Post.uri_query(post_uri) |> preload(:profile))
    |> then(fn post ->
      if post do
        if profile = post.profile do
          Map.put(post, :attributed_to, profile.uri)
        end
      end || post
    end)
  end

  @spec get_or_fetch_public_post_by_uri(binary, map) :: map | nil
  def get_or_fetch_public_post_by_uri(post_uri, %{} = current_profile) do
    get_public_post_by_uri(post_uri) ||
      fetch_public_post_by_uri(post_uri, %{} = current_profile)
  end

  @spec fetch_public_post_by_uri(binary, map) :: map | nil
  def fetch_public_post_by_uri(post_uri, %{} = current_profile) do
    case HttpClient.activity_get(post_uri) do
      {:ok, %{body: body}} -> new_public_post_from_response(body, current_profile)
      _ -> nil
    end
  end

  @spec new_public_post_from_response(map, map) :: map
  def new_public_post_from_response(
        %{"id" => post_uri} = body,
        %{"uri" => profile_uri} = _current_profile
      ) do
    profile_id = Map.get(body, "attributedTo")

    unless profile_id do
      Logger.info("attributedTo not found in #{inspect(body)}")
      throw(:reject)
    end

    content_html = Map.get(body, "content")
    in_reply_to_uri = Map.get(body, "inReplyTo")

    published =
      case Timex.parse(Map.get(body, "published"), "{RFC3339}") do
        {:ok, datetime} -> datetime
        _ -> Timex.now()
      end

    context_uri =
      cond do
        context = Map.get(body, "context") ->
          context

        conversation = Map.get(body, "conversation") ->
          conversation

        true ->
          # Generate a new tag URI if context is missing.
          %{host: domain} = URI.new!(profile_uri)
          random = Base58Check.Base58.encode(:crypto.strong_rand_bytes(16))
          specific = "context/#{random}"
          TagUri.generate(domain, specific)
      end

    %{
      uri: post_uri,
      origin: :remote,
      status: :published,
      visibility: :unlisted,
      content_html: content_html,
      context_uri: context_uri,
      in_reply_to_uri: in_reply_to_uri,
      published_at: published
    }
    |> Map.put(:attributed_to, profile_id)
  end

  def new_public_post_from_response(body, current_profile) do
    Logger.info(
      "public post #{inspect(body)} does not have required attributes for current profile #{inspect(current_profile)}"
    )

    nil
  end

  def insert_or_update_public_post_profile(attrs) do
    {profile_attrs, post_attrs} = Map.pop(attrs, :profile)

    profile_uri = Map.get(profile_attrs, :uri)

    profile_changeset =
      (Profiles.get_public_profile_by_uri(profile_uri) || %Profile{})
      |> Profile.changeset(profile_attrs)

    post_uri = Map.get(post_attrs, :uri)

    post_changeset =
      get_public_post_by_uri(post_uri) ||
        %Post{}
        |> Post.changeset(post_attrs)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert_or_update(:profile, profile_changeset)
      |> Ecto.Multi.insert_or_update(:post, fn %{profile: profile} ->
        post_changeset |> Ecto.Changeset.change(%{profile: profile})
      end)
      |> Repo.transaction()

    result
  end
end
