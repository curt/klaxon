defmodule Klaxon.Contents do
  @moduledoc """
  Interactions between `Klaxon.Contents` schemas and repo.
  """
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
end
