defmodule Klaxon.Profiles do
  require Logger
  alias Klaxon.Repo
  alias Klaxon.Auth.User
  alias Klaxon.Profiles.Principal
  alias Klaxon.Profiles.Profile
  alias Klaxon.HttpClient
  import Ecto.Query
  import Ecto.Changeset

  def list_principals(user_id) do
    query =
      Principal
      |> where([p], p.user_id == ^user_id)
      |> preload(:profile)

    Repo.all(query)
  end

  def get_principal(id) do
    case Repo.get(Principal, id) do
      %Principal{} = principal -> {:ok, principal}
      _ -> {:error, :not_found}
    end
  end

  def get_profile_by_uri(uri) do
    case Repo.one(
           from p0 in Profile.uri_query(uri),
             left_join: p1 in assoc(p0, :principals),
             preload: [principals: p1]
         ) do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end

  def get_local_profile_by_uri(uri) do
    case Cachex.fetch(:local_profile_cache, uri, &get_local_profile_by_uri_cache_miss/1) do
      {:ok, %Profile{} = profile} ->
        Logger.info("Cache hit for local profile: #{uri}")
        {:ok, profile}

      {:commit, %Profile{} = profile, _} ->
        Logger.info("Cache miss for local profile: #{uri}")
        {:ok, profile}

      _ ->
        Logger.info("Cache ignore for local profile: #{uri}")
        {:error, :not_found}
    end
  end

  defp get_local_profile_by_uri_cache_miss(uri) do
    with {:ok, profile} <- get_profile_by_uri(uri) do
      case profile.principals do
        # TODO: Make cache TTL configurable.
        [_ | _] -> {:commit, profile, ttl: :timer.seconds(300)}
        _ -> {:ignore, nil}
      end
    else
      _ ->
        {:ignore, nil}
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

  def is_profile_owned_by_user?(%Profile{principals: [_ | _] = principals}, %User{} = user) do
    Enum.any?(principals, fn principal -> is_principal_owned_by_user?(principal, user) end)
  end

  def is_profile_owned_by_user?(_, _), do: false

  def is_principal_owned_by_user?(%Principal{user_id: principal_user_id}, %User{id: user_id}) do
    principal_user_id == user_id
  end

  def is_principal_owned_by_user?(_, _), do: false

  def get_profile!(user_id, name) do
    query =
      Profile
      |> where([profile], profile.name == ^name)
      |> join(:inner, [profile], principal in assoc(profile, :principals))
      |> where([profile, principal], principal.user_id == ^user_id)

    Repo.one!(query)
  end

  def get_local_profile!(name) do
    query =
      Profile
      |> where([profile], profile.name == ^name)
      |> join(:inner, [profile], principal in assoc(profile, :principals))

    Repo.one!(query)
  end

  @spec get_public_profile_by_uri(binary) :: struct | nil
  def get_public_profile_by_uri(profile_uri) do
    Repo.one(Profile.uri_query(profile_uri))
  end

  @spec get_or_fetch_public_profile_by_uri(binary) :: struct | map | nil
  def get_or_fetch_public_profile_by_uri(profile_uri) do
    get_public_profile_by_uri(profile_uri) || fetch_public_profile_by_uri(profile_uri)
  end

  @spec fetch_public_profile_by_uri(binary) :: map | nil
  def fetch_public_profile_by_uri(profile_uri) do
    case HttpClient.activity_get(profile_uri) do
      {:ok, %{body: body}} -> new_public_profile_from_response(body)
      _ -> nil
    end
  end

  @spec new_public_profile_from_response(map) :: map | nil
  def new_public_profile_from_response(
        %{"id" => uri, "preferredUsername" => name, "inbox" => inbox} = body
      ) do
    public_key = Map.get(body, "publicKey")
    public_key_pem = public_key && Map.get(public_key, "publicKeyPem")

    %{
      uri: uri,
      name: name,
      inbox: inbox,
      summary: Map.get(body, "summary"),
      display_name: Map.get(body, "name"),
      public_key: public_key_pem
    }
  end

  def new_public_profile_from_response(_body) do
    Logger.info("public profile does not have required attributes")
    nil
  end

  def insert_or_update_profile(profile) do
    profile
    |> change()
    |> Repo.insert_or_update()
  end

  def create_local_profile(params, user_id) do
    {public_key, private_key} = create_rsa_pair()

    changeset =
      params
      |> Map.merge(%{public_key: public_key, private_key: private_key})
      |> Profile.insert_changeset()

    with {:ok, %{principal: _, profile: profile}} = results <-
           Ecto.Multi.new()
           |> Ecto.Multi.insert(:profile, changeset)
           |> Ecto.Multi.insert(:principal, fn %{profile: profile} ->
             %Principal{user_id: user_id, profile: profile}
           end)
           |> Repo.transaction() do
      {:ok, true} = Cachex.del(:local_profile_cache, profile.uri)
      Logger.info("Cache delete for local profile: #{profile.uri}")
      results
    end
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

  def create_rsa_pair() do
    private_key = X509.PrivateKey.new_rsa(2048)
    public_key = X509.PublicKey.derive(private_key)
    {X509.PublicKey.to_pem(public_key), X509.PrivateKey.to_pem(private_key)}
  end

  def delete_profile(%Profile{} = profile) do
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:principal, Principal.profile_query(profile))
    |> Ecto.Multi.delete(:profile, profile)
    |> Repo.transaction()
  end
end
