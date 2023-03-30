defmodule Klaxon.Activities do
  alias Klaxon.Repo
  alias Klaxon.HttpClient
  alias Klaxon.Profiles
  alias Klaxon.Activities.Ping
  alias Klaxon.Activities.Pong
  import Ecto.Query

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
    send_pong(profile, ping.to_uri, ping.uri)
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

  @spec send_activity(map, String.t(), String.t()) :: any
  defp send_activity(%{} = activity, to, profile) do
    {:ok, from} = Profiles.get_local_profile_by_uri(profile)
    to = Profiles.get_or_fetch_public_profile_by_uri(to)

    # FIXME: Lookup key from repository.
    HttpClient.post(Map.fetch!(to, :inbox), activity,
      opts: [private_key: from.private_key, key_id: from.uri <> "#key"]
    )
  end

  @spec contextify(map) :: map
  defp contextify(%{} = activity) do
    Map.put(activity, "@context", "https://www.w3.org/ns/activitystreams")
  end
end
