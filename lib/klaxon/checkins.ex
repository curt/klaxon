defmodule Klaxon.Checkins do
  @moduledoc """
  The Checkins context.
  """
  require Logger

  alias Klaxon.Auth.User
  alias Klaxon.Repo
  alias Klaxon.Checkins.Checkin
  alias Klaxon.Profiles

  @doc """
  Gets checkins for a specific place belonging to a profile.

  Returns a list of checkins filtered by the profile URI and place ID.
  The content is filtered based on user authentication:
  - If the user is the owner of the profile, all checkins are returned
  - If the user is not the owner, only public checkins are returned
  - If no user is provided, only public checkins are returned

  ## Parameters
    - `profile_uri` - URI of the profile that owns the checkins
    - `user` - The authenticated user or nil
    - `place_id` - ID of the place to get checkins for
    - `opts` - Additional options for filtering (default: %{})

  ## Examples

      iex> get_checkins("profile-uri", authenticated_user, "place-123")
      {:ok, [%Checkin{}, ...]}

      iex> get_checkins("profile-uri", nil, "place-123")
      {:ok, [%Checkin{}, ...]}
  """
  @spec get_checkins(String.t(), %User{id: String.t()} | nil, String.t(), map()) ::
          {:ok, [Checkin.t()]}
  def get_checkins(profile_uri, user, place_id, opts \\ %{})

  def get_checkins(profile_uri, %User{id: user_id, email: email} = _user, place_id, opts) do
    Logger.debug("Getting checkins authenticated as user: #{email}")
    get_checkins_authenticated(profile_uri, user_id, place_id, opts)
  end

  def get_checkins(profile_uri, _user, place_id, opts) do
    get_checkins_unauthorized(profile_uri, place_id, opts)
  end

  defp get_checkins_authenticated(profile_uri, user_id, place_id, opts) do
    if is_user_id_endpoint_principal?(profile_uri, user_id) do
      Logger.debug("Getting checkins as principal of profile: #{profile_uri}")
      get_checkins_authorized(profile_uri, place_id, opts)
    else
      get_checkins_unauthorized(profile_uri, place_id, opts)
    end
  end

  defp get_checkins_authorized(profile_uri, place_id, _opts) do
    checkins =
      Checkin.from_preloaded()
      |> Checkin.where_place_id(place_id)
      |> Checkin.where_authorized(profile_uri)
      |> Checkin.order_by_default()
      |> Repo.all()

    {:ok, checkins}
  end

  defp get_checkins_unauthorized(profile_uri, place_id, _opts) do
    checkins =
      Checkin.from_preloaded()
      |> Checkin.where_place_id(place_id)
      |> Checkin.where_public_list(profile_uri)
      |> Checkin.order_by_default()
      |> Repo.all()

    {:ok, checkins}
  end

  @doc """
  Gets a single checkin for a specific place belonging to a profile.

  Returns a single checkin filtered by the profile URI, place ID, and checkin ID.
  The access is filtered based on user authentication:
  - If the user is the owner of the profile, access to all checkins is granted
  - If the user is not the owner, only public and unlisted checkins are accessible
  - If no user is provided, only public and unlisted checkins are accessible

  ## Parameters
    - `profile_uri` - URI of the profile that owns the checkin
    - `user` - The authenticated user or nil
    - `place_id` - ID of the place the checkin belongs to
    - `id` - ID of the checkin to retrieve
    - `opts` - Additional options (default: %{})

  ## Returns
    - `{:ok, checkin}` if the checkin was found and accessible
    - `{:error, :not_found}` if the checkin was not found or not accessible

  ## Examples

      iex> get_checkin("profile-uri", authenticated_user, "place-123", "checkin-456")
      {:ok, %Checkin{}}

      iex> get_checkin("profile-uri", nil, "place-123", "non-existent-id")
      {:error, :not_found}
  """
  @spec get_checkin(String.t(), %User{id: String.t()} | nil, String.t(), String.t(), map()) ::
          {:ok, Checkin.t()} | {:error, :not_found}
  def get_checkin(profile_uri, user, place_id, id, opts \\ %{})

  def get_checkin(
        profile_uri,
        %User{id: user_id, email: email} = _user,
        place_id,
        id,
        opts
      ) do
    Logger.debug("Getting checkin authenticated as user: #{email}")
    get_checkin_authenticated(profile_uri, user_id, place_id, id, opts)
  end

  def get_checkin(profile_uri, _user, place_id, id, opts) do
    get_checkin_unauthorized(profile_uri, place_id, id, opts)
  end

  defp get_checkin_authenticated(profile_uri, user_id, place_id, id, opts) do
    if is_user_id_endpoint_principal?(profile_uri, user_id) do
      Logger.debug("Getting checkin as principal of profile: #{profile_uri}")
      get_checkin_authorized(profile_uri, place_id, id, opts)
    else
      get_checkin_unauthorized(profile_uri, place_id, id, opts)
    end
  end

  defp get_checkin_authorized(profile_uri, place_id, id, _opts) do
    case Checkin.from_preloaded()
         |> Checkin.where_place_id(place_id)
         |> Checkin.where_authorized(profile_uri)
         |> Checkin.where_id(id)
         |> Repo.one() do
      %Checkin{} = checkin ->
        {:ok, checkin}

      nil ->
        {:error, :not_found}
    end
  end

  defp get_checkin_unauthorized(profile_uri, place_id, id, _opts) do
    case Checkin.from_preloaded()
         |> Checkin.where_place_id(place_id)
         |> Checkin.where_public_single(profile_uri)
         |> Checkin.where_id(id)
         |> Repo.one() do
      %Checkin{} = checkin ->
        {:ok, checkin}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns the list of checkins.

  ## Examples

      iex> list_checkins()
      [%Checkin{}, ...]

  """
  def list_checkins do
    Repo.all(Checkin)
  end

  @doc """
  Gets a single checkin.

  Raises `Ecto.NoResultsError` if the Checkin does not exist.

  ## Examples

      iex> get_checkin!(123)
      %Checkin{}

      iex> get_checkin!(456)
      ** (Ecto.NoResultsError)

  """
  def get_checkin!(id), do: Repo.get!(Checkin, id)

  @doc """
  Creates a checkin.

  ## Examples

      iex> create_checkin(%{field: value})
      {:ok, %Checkin{}}

      iex> create_checkin(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_checkin(attrs \\ %{}) do
    %Checkin{}
    |> Checkin.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a checkin.

  ## Examples

      iex> update_checkin(checkin, %{field: new_value})
      {:ok, %Checkin{}}

      iex> update_checkin(checkin, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_checkin(%Checkin{} = checkin, attrs) do
    checkin
    |> Checkin.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a checkin.

  ## Examples

      iex> delete_checkin(checkin)
      {:ok, %Checkin{}}

      iex> delete_checkin(checkin)
      {:error, %Ecto.Changeset{}}

  """
  def delete_checkin(%Checkin{} = checkin) do
    Repo.delete(checkin)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking checkin changes.

  ## Examples

      iex> change_checkin(checkin)
      %Ecto.Changeset{data: %Checkin{}}

  """
  def change_checkin(%Checkin{} = checkin, attrs \\ %{}) do
    Checkin.changeset(checkin, attrs)
  end

  defp is_user_id_endpoint_principal?(endpoint, user_id) do
    case Profiles.get_profile_by_uri(endpoint) do
      {:ok, profile} -> profile.owner_id == user_id
      _ -> false
    end
  end
end
