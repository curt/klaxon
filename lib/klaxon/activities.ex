defmodule Klaxon.Activities do
  require Logger
  alias Klaxon.Repo
  alias Klaxon.HttpClient
  alias Klaxon.Profiles
  alias Klaxon.Activities.Ping
  alias Klaxon.Activities.Pong
  alias Klaxon.Activities.Follow
  alias Klaxon.Activities.Like
  import Ecto.Query

  @config Application.compile_env(:klaxon, Klaxon.Activities)

  @spec send_ping(String.t(), String.t()) :: any
  def send_ping(actor, to) do
    {:ok, ping} =
      Repo.insert(
        Ping.changeset(
          %Ping{},
          %{actor_uri: actor, to_uri: to, direction: :out},
          actor
        )
      )

    case %{"type" => "Ping", "id" => ping.uri, "actor" => actor, "to" => to}
         |> contextify()
         |> send_activity(to, actor) do
      {:ok, _} -> {:ok, ping}
      result -> {:cancel, inspect(result)}
    end
  end

  @spec receive_ping(map, String.t()) :: any
  def receive_ping(%{} = activity, profile) do
    {:ok, ping} =
      Repo.insert(
        Ping.changeset(
          %Ping{},
          %{
            actor_uri: activity["actor"].uri,
            uri: activity["id"],
            to_uri: activity["to"],
            direction: :in
          },
          profile
        )
      )

    # TODO: Make this configurable.
    send_pong(profile, ping.actor_uri, ping.uri)
  end

  @spec get_pings(String.t()) :: {:ok, any}
  def get_pings(profile_uri) do
    {:ok,
     Repo.all(
       from p in Ping,
         where: p.actor_uri == ^profile_uri or p.to_uri == ^profile_uri,
         order_by: [desc: p.inserted_at]
     )}
  end

  @spec get_ping(String.t(), String.t()) :: {:ok, any}
  def get_ping(profile_uri, id) do
    {:ok,
     Repo.one(
       from p in Ping,
         where: p.actor_uri == ^profile_uri or p.to_uri == ^profile_uri,
         where: p.id == ^id
     )}
  end

  @spec change_ping(URI.t() | binary, any, any) :: Ecto.Changeset.t() | nil
  def change_ping(profile, ping, attrs \\ %{}) do
    Ping.changeset(ping, attrs, profile)
  end

  @spec send_pong(String.t(), String.t(), String.t()) :: any
  def send_pong(actor, to, ping) do
    {:ok, pong} =
      Repo.insert(
        Pong.changeset(
          %Pong{},
          %{actor_uri: actor, to_uri: to, object_uri: ping, direction: :out},
          actor
        )
      )

    case %{"type" => "Pong", "id" => pong.uri, "actor" => actor, "to" => to, "object" => ping}
         |> contextify()
         |> send_activity(to, actor) do
      {:ok, _} -> :ok
      result -> {:cancel, inspect(result)}
    end
  end

  @spec receive_pong(map, String.t()) :: any
  def receive_pong(%{} = activity, profile) do
    {:ok, _pong} =
      Repo.insert(
        Pong.changeset(
          %Pong{},
          %{
            actor_uri: activity["actor"].uri,
            uri: activity["id"],
            to_uri: activity["to"],
            object_uri: activity["object"],
            direction: :in
          },
          profile
        )
      )
  end

  @spec get_pongs(String.t()) :: {:ok, any}
  def get_pongs(profile_uri) do
    {:ok,
     Repo.all(
       from p in Pong,
         where: p.actor_uri == ^profile_uri or p.to_uri == ^profile_uri,
         order_by: [desc: p.inserted_at]
     )}
  end

  @spec get_pong(String.t(), String.t()) :: {:ok, any}
  def get_pong(profile_uri, id) do
    {:ok,
     Repo.one(
       from p in Pong,
         where: p.actor_uri == ^profile_uri or p.to_uri == ^profile_uri,
         where: p.id == ^id
     )}
  end

  def get_follow(uri, _follower_uri, _followee_uri) when is_binary(uri) do
    case Repo.one(from f in Follow, where: f.uri == ^uri) do
      %Follow{} = follow -> {:ok, follow}
      _ -> {:error, :not_found}
    end
  end

  def get_follow(_uri, follower_uri, followee_uri)
      when is_binary(follower_uri) and is_binary(followee_uri) do
    case Repo.one(
           from f in Follow,
             where: f.follower_uri == ^follower_uri,
             where: f.followee_uri == ^followee_uri
         ) do
      %Follow{} = follow -> {:ok, follow}
      _ -> {:error, :not_found}
    end
  end

  def get_follow(_uri, _follower_uri, _followee_uri) do
    {:error, :not_found}
  end

  def receive_follow(uri, follower_uri, followee_uri, profile) do
    follow =
      case get_follow(nil, follower_uri, followee_uri) do
        {:ok, follow} ->
          update_follow(follow, %{uri: uri, status: :requested}, profile)

        _ ->
          create_follow(
            %{
              uri: uri,
              follower_uri: follower_uri,
              followee_uri: followee_uri,
              status: :requested
            },
            profile
          )
      end

    case follow do
      {:ok, _} ->
        send_follow_accepted(uri, follower_uri, followee_uri, profile)

      _ ->
        {:error, :not_found}
    end
  end

  def send_follow_accepted(uri, follower_uri, followee_uri, profile) do
    with {:ok, _} <-
           send_activity(
             %{
               "type" => "Accept",
               "id" => "#{uri}#accept",
               "actor" => followee_uri,
               "to" => follower_uri,
               "object" => %{
                 "type" => "Follow",
                 "id" => uri,
                 "actor" => follower_uri,
                 "object" => followee_uri
               }
             },
             follower_uri,
             profile
           ),
         {:ok, follow} <- get_follow(uri, follower_uri, followee_uri) do
      update_follow(follow, %{status: :accepted}, profile)
    end
  end

  def receive_undo_follow(uri, follower_uri, followee_uri, profile) do
    with {:ok, follow} <- get_follow(uri, follower_uri, followee_uri) do
      update_follow(follow, %{status: :undone}, profile)
    end
  end

  def get_like(actor_uri, object_uri) do
    Repo.one(from l in Like, where: l.actor_uri == ^actor_uri and l.object_uri == ^object_uri)
  end

  def get_likes(object_uri) do
    Repo.all(from l in Like, where: l.object_uri == ^object_uri, preload: [:actor])
  end

  def create_like(attrs, endpoint) do
    %Like{} |> Like.changeset(attrs, endpoint) |> Repo.insert(on_conflict: :nothing)
  end

  def delete_like(%Like{} = like) do
    Repo.delete(like)
  end

  def receive_like(uri, actor_uri, object_uri, profile) do
    create_like(%{uri: uri, actor_uri: actor_uri, object_uri: object_uri}, profile)
  end

  def receive_undo_like(actor_uri, object_uri) do
    get_like(actor_uri, object_uri) |> delete_like()
  end

  def resolve_undoable(uri) do
    with {:error, _} <- get_follow(uri, nil, nil) do
      nil
    else
      {:ok, struct} -> struct
      _ -> :error
    end
  end

  @spec send_activity(map, String.t(), String.t()) :: any
  defp send_activity(%{} = activity, to, profile) do
    if @config[:send_activities] do
      {:ok, from} = Profiles.get_local_profile_by_uri(profile)
      to = Profiles.get_or_fetch_public_profile_by_uri(to)

      Logger.info(
        "Sending\n --> activity --> #{inspect(activity)}\n\n --> from --> #{inspect(from)}\n\n --> to --> #{inspect(to)}"
      )

      # FIXME: Lookup key from repository.
      HttpClient.post(Map.fetch!(to, :inbox), activity,
        headers: [{"content-type", "application/activity+json"}],
        opts: [private_key: from.private_key, key_id: from.uri <> "#key"]
      )
    else
      {:ok, nil}
    end
  end

  @spec contextify(map) :: map
  defp contextify(%{} = activity) do
    Map.put(activity, "@context", "https://www.w3.org/ns/activitystreams")
  end

  @doc """
  Returns the list of follows.

  ## Examples

      iex> list_follows()
      [%Follow{}, ...]

  """
  def list_follows do
    Repo.all(Follow)
  end

  @doc """
  Gets a single follow.

  Raises `Ecto.NoResultsError` if the Follow does not exist.

  ## Examples

      iex> get_follow!(123)
      %Follow{}

      iex> get_follow!(456)
      ** (Ecto.NoResultsError)

  """
  def get_follow!(id), do: Repo.get!(Follow, id)

  @doc """
  Creates a follow.

  ## Examples

      iex> create_follow(%{field: value})
      {:ok, %Follow{}}

      iex> create_follow(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_follow(attrs, endpoint) do
    %Follow{}
    |> Follow.changeset(attrs, endpoint)
    |> Repo.insert()
  end

  @doc """
  Updates a follow.

  ## Examples

      iex> update_follow(follow, %{field: new_value})
      {:ok, %Follow{}}

      iex> update_follow(follow, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_follow(%Follow{} = follow, attrs, endpoint) do
    follow
    |> Follow.changeset(attrs, endpoint)
    |> Repo.update()
  end

  @doc """
  Deletes a follow.

  ## Examples

      iex> delete_follow(follow)
      {:ok, %Follow{}}

      iex> delete_follow(follow)
      {:error, %Ecto.Changeset{}}

  """
  def delete_follow(%Follow{} = follow) do
    Repo.delete(follow)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking follow changes.

  ## Examples

      iex> change_follow(follow)
      %Ecto.Changeset{data: %Follow{}}

  """
  def change_follow(%Follow{} = follow, attrs, endpoint) do
    Follow.changeset(follow, attrs, endpoint)
  end

  def send_object(actor, object, action, follower) do
    %{
      "type" => send_type(action),
      "id" => "#{object}#activity/#{action}",
      "actor" => actor,
      "object" => object
    }
    |> contextify()
    |> send_activity(follower, actor)
  end

  defp send_type(action) do
    case action do
      "create" -> "Create"
      "update" -> "Update"
      "tombstone" -> "Delete"
    end
  end
end
