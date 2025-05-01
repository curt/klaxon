defmodule Klaxon.Checkins do
  @moduledoc """
  The Checkins context.
  """
  require Logger

  alias Klaxon.Checkins.CheckinAttachment
  alias Klaxon.Auth.User
  alias Klaxon.Repo
  alias Klaxon.Checkins.Checkin
  alias Klaxon.Media
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

  @doc ~S"""
  Creates a checkin for a specific profile and place.

  ## Parameters
    - `profile` - The profile creating the checkin
    - `place_id` - The ID of the place being checked into
    - `attrs` - Attributes for the checkin
    - `uri_fun` - Function to generate URI based on ID

  ## Returns
    - `{:ok, checkin}` if the checkin was created successfully
    - `{:error, changeset}` if there was a validation error

  ## Examples

      iex> insert_checkin(profile, place_id, %{source: "Had a great time!"}, &("https://example.com/#{&1}"))
      {:ok, %Checkin{}}
  """
  @spec insert_checkin(any(), String.t(), map(), (String.t() -> String.t())) ::
          {:ok, Checkin.t()} | {:error, Ecto.Changeset.t()}
  def insert_checkin(profile, place_id, attrs, uri_fun) do
    id = EctoBase58.generate()
    uri = uri_fun.(id)

    %Checkin{
      id: id,
      uri: uri,
      profile_id: profile.id,
      place_id: place_id,
      origin: :local,
      checked_in_at: Map.get(attrs, :checked_in_at, DateTime.utc_now())
    }
    |> Checkin.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a checkin for a specific profile.

  Ensures the checkin belongs to the specified profile before updating.

  ## Parameters
    - `profile` - The profile that owns the checkin
    - `checkin` - The checkin to update
    - `attrs` - New attributes for the checkin

  ## Returns
    - `{:ok, checkin}` if the checkin was updated successfully
    - `{:error, :unauthorized}` if the checkin doesn't belong to the profile
    - `{:error, changeset}` if there was a validation error

  ## Examples

      iex> update_checkin(profile, checkin, %{source: "Updated message"})
      {:ok, %Checkin{}}
  """
  @spec update_checkin(any(), Checkin.t(), map()) ::
          {:ok, Checkin.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def update_checkin(profile, %Checkin{} = checkin, attrs) do
    if checkin.profile_id == profile.id do
      checkin
      |> Checkin.changeset(attrs)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes a checkin for a specific profile.

  Ensures the checkin belongs to the specified profile before deleting.

  ## Parameters
    - `profile` - The profile that owns the checkin
    - `checkin` - The checkin to delete

  ## Returns
    - `{:ok, checkin}` if the checkin was deleted successfully
    - `{:error, :unauthorized}` if the checkin doesn't belong to the profile
    - `{:error, changeset}` if there was an error during deletion

  ## Examples

      iex> delete_checkin(profile, checkin)
      {:ok, %Checkin{}}
  """
  @spec delete_checkin(any(), Checkin.t()) ::
          {:ok, Checkin.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
  def delete_checkin(profile, %Checkin{} = checkin) do
    if checkin.profile_id == profile.id do
      Repo.delete(checkin)
    else
      {:error, :unauthorized}
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

  def get_checkin_attachment(id) do
    case Repo.get(CheckinAttachment, id) do
      nil -> {:error, :not_found}
      checkin_attachment -> {:ok, checkin_attachment}
    end
  end

  def insert_checkin_attachment(checkin_id, attrs, path, content_type, url_fun)
      when is_function(url_fun, 3) do
    with {:ok, media} <- Media.insert_local_media(path, content_type, :checkin, url_fun) do
      %CheckinAttachment{checkin_id: checkin_id, media_id: media.id}
      |> CheckinAttachment.changeset(attrs)
      |> Repo.insert()
    end
  end

  def update_checkin_attachment(checkin_attachment, attrs) do
    checkin_attachment
    |> CheckinAttachment.changeset(attrs)
    |> Repo.update()
  end

  def delete_checkin_attachment(checkin_attachment) do
    checkin_attachment
    |> Repo.delete()
  end

  defp is_user_id_endpoint_principal?(endpoint, user_id) do
    case Profiles.get_profile_by_uri(endpoint) do
      {:ok, profile} -> profile.owner_id == user_id
      _ -> false
    end
  end
end
