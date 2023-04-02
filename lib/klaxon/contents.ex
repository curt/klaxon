defmodule Klaxon.Contents do
  @moduledoc """
  Interactions between `Klaxon.Contents` schemas and repo.
  """
  require Logger
  alias Klaxon.HttpClient
  alias Klaxon.Repo
  alias Klaxon.Auth.User
  alias Klaxon.Profiles
  #alias Klaxon.Profiles.Profile
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
  def get_posts(endpoint, %User{id: user_id, email: email} = _user) do
    Logger.debug("Getting posts authenticated as user: #{email}")
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
  def get_post(endpoint, post_id, %User{id: user_id, email: email} = _user) do
    Logger.debug("Getting post authenticated as user: #{email}")
    get_post_authenticated(endpoint, post_id, user_id)
  end

  def get_post(endpoint, post_id, _) do
    get_post_unauthenticated(endpoint, post_id)
  end

  defp get_posts_authenticated(endpoint, user_id) do
    if is_user_id_endpoint_principal?(endpoint, user_id) do
      Logger.debug("Getting posts as principal of endpoint: #{endpoint}")
      get_posts_authorized(endpoint)
    else
      get_posts_unauthenticated(endpoint)
    end
  end

  defp get_posts_authorized(endpoint) do
    case Post.from_preloaded()
         |> where_authorized(endpoint)
         |> Post.order_by_default()
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

  def change_post(endpoint, post, attrs \\ %{}) do
    Post.changeset(post, attrs, endpoint)
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
    case Cachex.fetch(
           :get_post_cache,
           post_uri,
           fn key ->
             case Repo.one(
                    Post.uri_query(key)
                    |> Post.where_status([:published])
                    |> Post.where_visibility([:public, :unlisted])
                    |> preload(:profile)
                  ) do
               %Post{} = post ->
                 {:commit,
                  if profile = post.profile do
                    Map.put(post, :attributed_to, profile.uri)
                  end || post}

               _ ->
                 {:ignore, nil}
             end
           end,
           ttl: 300
         ) do
      {:ok, %Post{} = post} ->
        Logger.info("Cache hit for get post: #{post_uri}")
        post

      {:commit, %Post{} = post} ->
        Logger.info("Cache miss for get post: #{post_uri}")
        post

      _ ->
        Logger.info("Cache ignore for get post: #{post_uri}")
        nil
    end
  end

  @spec get_or_fetch_public_post_by_uri(binary) :: map | nil
  def get_or_fetch_public_post_by_uri(post_uri) do
    get_public_post_by_uri(post_uri) ||
      fetch_public_post_by_uri(post_uri)
  end

  @spec fetch_public_post_by_uri(binary) :: map | nil
  defp fetch_public_post_by_uri(post_uri) do
    case Cachex.fetch(
           :fetch_post_cache,
           post_uri,
           fn key ->
             case HttpClient.get(key) do
               {:ok, %{body: body}} ->
                 {:commit, new_public_post_from_response(body)}

               _ ->
                 {:ignore, nil}
             end
           end,
           ttl: 300
         ) do
      {:ok, %{} = post} ->
        Logger.info("Cache hit for fetch post: #{post_uri}")
        post

      {:commit, %{} = post} ->
        Logger.info("Cache miss for fetch post: #{post_uri}")
        post

      _ ->
        Logger.info("Cache ignore for fetch post: #{post_uri}")
        nil
    end
  end

  @spec new_public_post_from_response(map) :: map
  defp new_public_post_from_response(%{"id" => post_uri} = body) do
    profile_id = Map.get(body, "attributedTo")

    unless profile_id do
      Logger.info("attributedTo not found in #{inspect(body)}")
      throw(:reject)
    end

    %{
      uri: post_uri,
      origin: :remote,
      status: :published,
      visibility: :unlisted,
      content_html: body["content"],
      context_uri: body["context"] || body["conversation"],
      in_reply_to_uri: body["inReplyTo"],
      published_at: time_parse_rfc3339_or_now(body["published"])
    }
    |> Map.put(:attributed_to, profile_id)
  end

  defp new_public_post_from_response(body) do
    Logger.info("public post #{inspect(body)} does not have required attributes")
    nil
  end

  def insert_or_update_public_post(attrs, endpoint) do
    post_uri = Map.get(attrs, :uri)

    post_changeset =
      (get_public_post_by_uri(post_uri) || %Post{})
      |> Post.changeset(attrs, endpoint)

    Repo.insert_or_update(post_changeset)
  end

  # def insert_or_update_public_post_profile(attrs, endpoint) do
  #   {profile_attrs, post_attrs} = Map.pop(attrs, :profile)

  #   profile_uri = Map.get(profile_attrs, :uri)

  #   profile_changeset =
  #     (Profiles.get_public_profile_by_uri(profile_uri) || %Profile{})
  #     |> Profile.changeset(profile_attrs)

  #   post_uri = Map.get(post_attrs, :uri)

  #   post_changeset =
  #     get_public_post_by_uri(post_uri) ||
  #       %Post{}
  #       |> Post.changeset(post_attrs, URI.new!(endpoint))

  #   result =
  #     Ecto.Multi.new()
  #     |> Ecto.Multi.insert_or_update(:profile, profile_changeset)
  #     |> Ecto.Multi.insert_or_update(:post, fn %{profile: profile} ->
  #       post_changeset |> Ecto.Changeset.change(%{profile: profile})
  #     end)
  #     |> Repo.transaction()

  #   result
  # end

  defp time_parse_rfc3339_or_now(nil) do
    Timex.now()
  end

  defp time_parse_rfc3339_or_now(rfc3339_datetime_string) do
    Timex.parse!(rfc3339_datetime_string, "{RFC3339}")
  end
end
