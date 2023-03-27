defmodule Klaxon.Activities do
  alias Klaxon.Repo
  alias Klaxon.HttpClient
  alias Klaxon.Profiles
  alias Klaxon.Activities.Ping
  alias Klaxon.Activities.Pong

  @spec send_ping(URI.t(), String.t()) :: any
  def send_ping(profile, to) do
    actor = URI.to_string(profile)

    {:ok, ping} =
      Repo.insert(
        Ping.changeset(
          %Ping{},
          %{actor_uri: actor, to_uri: to, direction: :out},
          profile
        )
      )

    %{"type" => "Ping", "id" => ping.uri, "actor" => actor, "to" => to}
    |> contextify()
    |> send_activity(to, profile)
  end

  def receive_ping(%{} = activity, profile) do
    {:ok, _ping} =
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
  end

  @spec send_pong(URI.t(), String.t(), String.t()) :: any
  def send_pong(profile, to, ping) do
    actor = URI.to_string(profile)

    {:ok, pong} =
      Repo.insert(
        Pong.changeset(
          %Pong{},
          %{actor_uri: actor, to_uri: to, object_uri: ping, direction: :out},
          profile
        )
      )

    %{"type" => "Pong", "id" => pong.uri, "actor" => actor, "to" => to, "object" => ping}
    |> contextify()
    |> send_activity(to, profile)
  end

  @spec send_activity(map, String.t(), URI.t()) :: any
  def send_activity(%{} = activity, to, profile) do
    {:ok, from} = Profiles.get_local_profile_by_uri(URI.to_string(profile))
    to = Profiles.get_or_fetch_public_profile_by_uri(to)

    HttpClient.activity_signed_post(Map.fetch!(to, :inbox), activity, from.private_key, from.uri)
  end

  @spec contextify(map) :: map
  def contextify(%{} = activity) do
    Map.put(activity, "@context", "https://www.w3.org/ns/activitystreams")
  end
end
