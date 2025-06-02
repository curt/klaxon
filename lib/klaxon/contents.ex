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
  alias Klaxon.Contents.PostAttachment
  alias Klaxon.Contents.PostPlace
  alias Klaxon.Contents.Place
  alias Klaxon.Federation
  alias Klaxon.Media
  import Ecto.Query

  @callback maybe_associate_post_with_place(Post.t(), (binary() -> binary())) ::
              {:ok, PostPlace.t()} | {:error, Ecto.Changeset.t() | :missing_fields}

  @doc """
  Gets posts from repo for given endpoint and user (if specified).
  """
  @spec get_posts(String.t(), %Klaxon.Auth.User{id: String.t()} | nil, any) ::
          {:error, :not_found} | {:ok, maybe_improper_list}
  def get_posts(endpoint, user, options \\ %{})

  def get_posts(endpoint, %User{id: user_id, email: email} = _user, options) do
    Logger.debug("Getting posts authenticated as user: #{email}")
    get_posts_authenticated(endpoint, user_id, options)
  end

  def get_posts(endpoint, _user, options) do
    get_posts_unauthenticated(endpoint, options)
  end

  defp get_posts_authenticated(endpoint, user_id, options) do
    if is_user_id_endpoint_principal?(endpoint, user_id) do
      Logger.debug("Getting posts as principal of endpoint: #{endpoint}")
      get_posts_authorized(endpoint, options)
    else
      get_posts_unauthenticated(endpoint, options)
    end
  end

  defp get_posts_authorized(endpoint, options) do
    case Post.from_preloaded()
         |> where_authorized(endpoint)
         |> Post.order_by_default()
         |> maybe_limit(options)
         |> Repo.all() do
      posts when is_list(posts) -> {:ok, posts}
      _ -> {:error, :not_found}
    end
  end

  defp get_posts_unauthenticated(endpoint, options) do
    case Post.from_preloaded()
         |> where_unauthenticated_list(endpoint)
         |> Post.order_by_default()
         |> maybe_limit(options)
         |> Repo.all() do
      posts when is_list(posts) -> {:ok, posts}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Gets post from repo for given endpoint, identifier, and user (if specified).
  """
  @spec get_post(String.t(), String.t(), %Klaxon.Auth.User{id: String.t()} | nil) ::
          {:error, :not_found} | {:ok, %Klaxon.Contents.Post{id: String.t()}}
  def get_post(_endpoint, post_id, user) do
    case Post.from_preloaded()
         |> Post.where_post_id(post_id)
         |> apply_context_authorization(user)
         |> Repo.one() do
      %Post{} = post -> {:ok, post}
      _ -> {:error, :not_found}
    end
  end

  def get_context(_endpoint, context_id, user, options \\ %{}) do
    Post.from_preloaded()
    |> Post.where_context_uri(context_id)
    |> apply_context_authorization(user)
    |> Post.order_by_default()
    |> maybe_limit(options)
    |> Repo.all()
  end

  defp apply_context_authorization(query, %User{}) do
    query
    |> Post.where_status([:published, :draft])
    |> Post.where_visibility([:public, :unlisted, :private])
  end

  defp apply_context_authorization(query, _) do
    query
    |> Post.where_status([:published])
    |> Post.where_visibility([:public, :unlisted])
  end

  def get_local_post_attachment(attachment_id) do
    case PostAttachment |> Repo.get(attachment_id) do
      %PostAttachment{} = attachment -> {:ok, attachment}
      _ -> {:error, :not_found}
    end
  end

  def change_post(host, post, attrs \\ %{}) do
    Post.changeset(post, attrs, host)
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

  defp where_local_published(query, endpoint) do
    query
    |> Post.where_profile_uri(endpoint)
    |> Post.where_origin([:local])
    |> Post.where_status([:published])
    |> Post.where_published_at()
  end

  defp where_unauthenticated_list(query, endpoint) do
    query
    |> where_local_published(endpoint)
    |> Post.where_visibility([:public])
  end

  defp maybe_limit(query, options) do
    case options[:limit] do
      lim when is_integer(lim) -> query |> limit(^lim)
      _ -> query
    end
  end

  defp is_user_id_endpoint_principal?(endpoint, user_id) do
    case Profiles.get_profile_by_uri(endpoint) do
      {:ok, profile} -> profile.owner_id == user_id
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
  def new_public_post_from_response(%{"id" => post_uri} = body) do
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

  def new_public_post_from_response(body) do
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

  defp maybe_federate_post({:ok, %{} = post} = result, %{} = changeset) do
    if length(Map.keys(changeset.changes)) > 0 do
      post = post |> maybe_load_post_profile()
      maybe_federate_post_with_changes(post, changeset)
    end

    result
  end

  defp maybe_federate_post(result, _), do: result

  defp maybe_load_post_profile(%Post{profile: %{uri: _}} = post), do: post

  defp maybe_load_post_profile(%Post{profile_id: profile_id} = post) do
    profile = Profile |> where(id: ^profile_id) |> Repo.one!()
    Map.put(post, :profile, profile)
  end

  defp maybe_federate_post_with_changes(post, %{changes: %{status: :published}}) do
    Logger.info("Federating post: #{post.uri} CREATE")
    Federation.generate_activities(:post, post.profile.uri, post.uri, :create)
  end

  defp maybe_federate_post_with_changes(%{status: :published} = post, _) do
    Logger.info("Federating post: #{post.uri} UPDATE")
    Federation.generate_activities(:post, post.profile.uri, post.uri, :update)
  end

  defp maybe_federate_post_with_changes(%{status: :deleted} = post, %{data: %{status: :published}}) do
    Logger.info("Federating post: #{post.uri} TOMBSTONE")
    Federation.generate_activities(:post, post.profile.uri, post.uri, :tombstone)
  end

  defp maybe_federate_post_with_changes(_, _), do: nil

  def insert_local_post(attrs, profile_id, host, uri_fun) when is_function(uri_fun, 1) do
    id = EctoBase58.generate()
    uri = uri_fun.(id)

    changeset =
      %Post{id: id, uri: uri, profile_id: profile_id, origin: :local}
      |> Post.changeset(attrs, host)

    changeset
    |> Repo.insert()
    |> maybe_federate_post(changeset)
  end

  def insert_local_post_attachment(post_id, attrs, path, content_type, url_fun)
      when is_function(url_fun, 3) do
    with {:ok, media} <- Media.insert_local_media(path, content_type, :post, url_fun) do
      %PostAttachment{post_id: post_id, media_id: media.id}
      |> PostAttachment.changeset(attrs)
      |> Repo.insert()
    end
  end

  def update_local_post(post, attrs, host) do
    changeset =
      post
      |> Post.changeset(attrs, host)

    changeset
    |> Repo.update()
    |> maybe_federate_post(changeset)
  end

  def update_local_post_attachment(attachment, attrs) do
    attachment
    |> PostAttachment.changeset(attrs)
    |> Repo.update()
  end

  def delete_post_attachment(attachment) do
    attachment
    |> Repo.delete()
  end

  defp time_parse_rfc3339_or_now(nil) do
    Timex.now()
  end

  defp time_parse_rfc3339_or_now(rfc3339_datetime_string) do
    Timex.parse!(rfc3339_datetime_string, "{RFC3339}")
  end

  def update_public_posts_content_html() do
    for p <- Klaxon.Repo.all(get_posts_local_published_all()) do
      if p.source do
        Ecto.Changeset.change(p)
        |> Klaxon.Contents.Post.put_change_content_html(p.source)
        |> Klaxon.Repo.update()
      end
    end
  end

  defp get_posts_local_published_all() do
    from(posts in Post, as: :posts)
    |> Post.where_origin([:local])
    |> Post.where_status([:published])
  end

  @doc """
  Returns a list of places filtered by the given profile URI.
  """
  @spec get_places(String.t(), %Klaxon.Auth.User{id: String.t()} | nil, map()) ::
          {:ok, list(Place.t())}
  def get_places(profile_uri, user, options \\ %{})

  def get_places(profile_uri, %User{id: user_id, email: email} = _user, options) do
    Logger.debug("Getting places authenticated as user: #{email}")
    get_places_authenticated(profile_uri, user_id, options)
  end

  def get_places(profile_uri, _user, options) do
    get_places_unauthenticated(profile_uri, options)
  end

  defp get_places_authenticated(profile_uri, user_id, options) do
    if is_user_id_endpoint_principal?(profile_uri, user_id) do
      Logger.debug("Getting places as principal of profile: #{profile_uri}")
      get_places_authorized(profile_uri, options)
    else
      get_places_unauthenticated(profile_uri, options)
    end
  end

  defp get_places_authorized(profile_uri, options) do
    places =
      Place.from_preloaded()
      |> Place.where_authorized(profile_uri)
      |> Place.order_by_default()
      |> maybe_limit(options)
      |> Repo.all()

    {:ok, places}
  end

  defp get_places_unauthenticated(profile_uri, options) do
    places =
      Place.from_preloaded()
      |> Place.where_unauthenticated_list(profile_uri)
      |> Place.order_by_default()
      |> maybe_limit(options)
      |> Repo.all()

    {:ok, places}
  end

  @doc """
  Retrieves a single place belonging to the given profile URI.
  """
  @spec get_place(String.t(), String.t(), %Klaxon.Auth.User{id: String.t()} | nil) ::
          {:ok, Place.t()} | {:error, :not_found}
  def get_place(profile_uri, place_id, %User{id: user_id, email: email} = _user) do
    Logger.debug("Getting place authenticated as user: #{email}")
    get_place_authenticated(profile_uri, place_id, user_id)
  end

  def get_place(profile_uri, place_id, _user) do
    get_place_unauthenticated(profile_uri, place_id)
  end

  defp get_place_authenticated(profile_uri, place_id, user_id) do
    if is_user_id_endpoint_principal?(profile_uri, user_id) do
      get_place_authorized(profile_uri, place_id)
    else
      get_place_unauthenticated(profile_uri, place_id)
    end
  end

  defp get_place_authorized(profile_uri, place_id) do
    case Place.from_preloaded()
         |> Place.where_authorized(profile_uri)
         |> Place.where_place_id(place_id)
         |> Repo.one() do
      nil -> {:error, :not_found}
      place -> {:ok, place}
    end
  end

  defp get_place_unauthenticated(profile_uri, place_id) do
    case Place.from_preloaded()
         |> Place.where_unauthenticated_single(profile_uri)
         |> Place.where_place_id(place_id)
         |> Repo.one() do
      nil -> {:error, :not_found}
      place -> {:ok, place}
    end
  end

  @doc """
  Creates a new place associated with the given profile.
  """
  def insert_place(profile, attrs, uri_fun) do
    id = EctoBase58.generate()
    uri = uri_fun.(id)

    %Place{id: id, uri: uri, profile_id: profile.id, origin: :local}
    |> Place.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing place belonging to the given profile.
  """
  @spec update_place(map(), Place.t(), map()) :: {:ok, Place.t()} | {:error, Ecto.Changeset.t()}
  def update_place(profile, %Place{} = place, attrs) do
    if place.profile_id == profile.id do
      place
      |> Place.changeset(attrs)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes a place if it belongs to the given profile.
  """
  @spec delete_place(map(), Place.t()) :: {:ok, Place.t()} | {:error, :unauthorized}
  def delete_place(profile, %Place{} = place) do
    if place.profile_id == profile.id do
      Repo.delete(place)
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Associates posts with places where a post does not have any.
  """
  @spec maybe_associate_posts_with_post_place((binary() -> binary())) ::
          [
            {binary(), :ok, PostPlace.t() | nil}
            | {binary(), :error, Ecto.Changeset.t() | :missing_fields}
          ]
  def maybe_associate_posts_with_post_place(uri_fun) do
    module = Application.get_env(:klaxon, :contents_module, __MODULE__)

    posts = Repo.all(from p in Post, preload: [:post_places])

    for post <- posts do
      if Enum.empty?(post.post_places) do
        case module.maybe_associate_post_with_place(post, uri_fun) do
          {:ok, %PostPlace{place_id: place_id}} -> {post.id, :ok, place_id}
          {:error, :missing_fields} -> {post.id, :ok, nil}
          {:error, changeset} -> {post.id, :error, changeset}
        end
      else
        {post.id, :ok, nil}
      end
    end
  end

  @doc """
  Associates a post with a place if the post has location, lat, and lon fields.
  """
  @spec maybe_associate_post_with_place(Post.t(), (binary() -> binary())) ::
          {:ok, PostPlace.t()} | {:error, Ecto.Changeset.t() | :missing_fields}
  def maybe_associate_post_with_place(%Post{} = post, uri_fun) do
    if post.location && post.lat && post.lon do
      place = Repo.one(from p in Place, where: p.title == ^post.location)

      place =
        case place do
          nil ->
            id = EctoBase58.generate()
            uri = uri_fun.(id)

            %Place{}
            |> Place.changeset(%{
              id: id,
              uri: uri,
              title: post.location,
              lat: post.lat,
              lon: post.lon
            })
            |> Repo.insert!()

          place ->
            place
        end

      %PostPlace{}
      |> PostPlace.changeset(%{post_id: post.id, place_id: place.id})
      |> Repo.insert()
    else
      {:error, :missing_fields}
    end
  end
end
