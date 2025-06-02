defmodule Klaxon.Federation do
  import Ecto.Query
  alias Klaxon.Profiles.Profile
  alias Klaxon.Activities.Follow
  alias Klaxon.Federation.GenerationWorker
  alias Klaxon.Repo

  def generate_activities(schema, actor, object, action) do
    %{schema: schema, actor: actor, object: object, action: action}
    |> GenerationWorker.new(max_attempts: 3)
    |> Oban.insert()
  end

  def get_follower_uris(actor) do
    query =
      from(Profile, as: :profile)
      |> where([profile: u], u.uri == ^actor)
      |> join(:inner, [profile: u], f in Follow, as: :follows, on: f.followee_uri == u.uri)
      |> join(:inner, [follows: f], p in Profile, as: :followers, on: p.uri == f.follower_uri)
      |> select([followers: f], f.uri)

    Repo.all(query)
  end
end
