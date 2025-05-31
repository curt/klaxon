defmodule Klaxon.Federation do
  import Ecto.Query
  alias Klaxon.Profiles.Profile
  alias Klaxon.Activities.Follow
  alias Klaxon.Contents.Post
  alias Klaxon.Federation.GenerationWorker
  alias Klaxon.Repo

  def generate_activities_for_post(post_id, action) do
    %{type: :post, id: post_id, action: action}
    |> GenerationWorker.new()
    |> Oban.insert()
  end

  def get_follower_uris_for_post(post_id) do
    query =
      from(Post, as: :posts)
      |> where([posts: p], p.id == ^post_id)
      |> join(:inner, [posts: p], r in assoc(p, :profile), as: :profile)
      |> join(:inner, [profile: u], f in Follow, as: :follows, on: f.followee_uri == u.uri)
      |> join(:inner, [follows: f], p in Profile, as: :followers, on: p.uri == f.follower_uri)
      |> select([followers: f], f.uri)
      |> where([followers: f], not is_nil(f.inbox))

    Repo.all(query)
  end
end
