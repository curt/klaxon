defmodule Klaxon.Profiles do
  require Logger

  import Ecto.Query
  import Klaxon.Helpers

  alias Klaxon.Repo
  alias Klaxon.Auth.User
  alias Klaxon.Profiles.Profile
  alias Klaxon.HttpClient
  alias Klaxon.Media

  def get_profile_by_uri(profile_uri) do
    case Repo.one(profile_query_uri(profile_uri)) do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end

  def get_local_profile_by_uri(profile_uri) do
    case Repo.one(
           profile_query_uri(profile_uri)
           |> profile_query_where_local()
           |> preload(:owner)
         ) do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end

  def get_local_profile_by_uri_user(uri, %User{} = user) do
    with {:ok, profile} <- get_local_profile_by_uri(uri) do
      if is_profile_owned_by_user?(profile, user) do
        {:ok, profile}
      else
        {:error, :unauthorized}
      end
    end
  end

  def is_profile_owned_by_user?(%Profile{owner_id: owner_id}, %User{id: user_id}) do
    user_id == owner_id
  end

  def is_profile_owned_by_user?(_, _), do: false

  @spec get_public_profile_by_uri(binary) :: struct | nil
  def get_public_profile_by_uri(profile_uri) do
    case Repo.one(profile_query_uri(profile_uri) |> profile_query_where_fresh(600)) do
      %Profile{} = profile -> profile
      _ -> nil
    end
  end

  @spec get_or_fetch_public_profile_by_uri(binary) :: Klaxon.Profiles.Profile.t() | nil
  def get_or_fetch_public_profile_by_uri(profile_uri) do
    get_public_profile_by_uri(profile_uri) || fetch_public_profile_by_uri(profile_uri)
  end

  @spec fetch_public_profile_by_uri(binary) :: Klaxon.Profiles.Profile.t() | nil
  def fetch_public_profile_by_uri(profile_uri) do
    case HttpClient.get(profile_uri) do
      {:ok, %{body: body}} ->
        if profile = new_public_profile_from_response(body) do
          case insert_or_update_profile_by_uri(profile.uri, profile, force: true) do
            {:ok, profile} ->
              if profile.icon do
                Media.get_media_by_uri_scope(profile.icon, :profile) ||
                  Media.insert_remote_media(profile.icon)
              end

              profile

            _ ->
              nil
          end
        end

      _ ->
        nil
    end
  end

  @spec new_public_profile_from_response(map) :: map | nil
  def new_public_profile_from_response(
        %{"id" => uri, "preferredUsername" => name, "inbox" => inbox} = body
      ) do
    public_key = body["publicKey"]
    public_key_pem = public_key && public_key["publicKeyPem"]
    public_key_id = public_key && public_key["id"]
    {icon, icon_media_type} = decompose_media_object(body["icon"])
    {image, image_media_type} = decompose_media_object(body["image"])

    %{
      uri: uri,
      url: body["url"],
      name: name,
      inbox: inbox,
      summary: body["summary"],
      display_name: body["name"],
      public_key: public_key_pem,
      public_key_id: public_key_id,
      icon: icon,
      icon_media_type: icon_media_type,
      image: image,
      image_media_type: image_media_type
    }
  end

  def new_public_profile_from_response(_body) do
    Logger.info("public profile does not have required attributes")
    nil
  end

  def insert_or_update_profile_by_uri(uri, attrs, opts \\ []) do
    Repo.one(profile_query_uri(uri))
    |> Profile.upsert_changeset(attrs)
    |> Repo.insert_or_update(opts)
  end

  def create_local_profile(params, user_id) do
    {public_key, private_key} = create_rsa_pair()

    changeset =
      params
      |> Map.merge(%{public_key: public_key, private_key: private_key, owner_id: user_id})
      |> Profile.insert_changeset()

    Repo.insert(changeset)
  end

  def change_profile(%Profile{} = profile, attrs \\ %{}) do
    Profile.update_changeset(profile, attrs)
  end

  def update_profile(%Profile{} = profile, attrs) do
    with {:ok, %Profile{} = profile} = results <-
           change_profile(profile, attrs)
           |> Repo.update() do
      {:ok, true} = Cachex.del(:local_profile_cache, profile.uri)
      Logger.info("Cache delete for profile: #{profile.uri}")
      results
    end
  end

  def insert_local_profile_avatar(profile_id, path, content_type, url_fun)
      when is_function(url_fun, 3) do
    with {:ok, media} <- Media.insert_local_media(path, content_type, :profile, url_fun),
         %Profile{} = profile <- Repo.one(from p in Profile, where: p.id == ^profile_id) do
      profile
      |> Profile.update_changeset(%{
        icon_media_type: media.mime_type,
        icon: url_fun.(:profile, :raw, media.id)
      })
      |> Repo.update()
    end
  end

  def create_rsa_pair() do
    private_key = X509.PrivateKey.new_rsa(2048)
    public_key = X509.PublicKey.derive(private_key)
    {X509.PublicKey.to_pem(public_key), X509.PrivateKey.to_pem(private_key)}
  end

  def delete_profile(%Profile{} = profile) do
    Repo.delete(profile)
  end

  @spec profile_query_uri(binary) :: Ecto.Query.t()
  defp profile_query_uri(uri) do
    from p in Profile, where: p.uri == ^uri
  end

  @spec profile_query_where_fresh(Ecto.Query.t(), integer) :: Ecto.Query.t()
  defp profile_query_where_fresh(query, seconds) do
    cutoff = DateTime.add(DateTime.utc_now(), -seconds)
    where(query, [p], p.updated_at >= ^cutoff)
  end

  @spec profile_query_where_local(Ecto.Query.t()) :: Ecto.Query.t()
  defp profile_query_where_local(query) do
    where(query, [p], not is_nil(p.owner_id))
  end
end
