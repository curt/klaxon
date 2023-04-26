defmodule KlaxonWeb.RssController do
  use KlaxonWeb, :controller

  alias Klaxon.Contents
  alias Klaxon.Contents.Post
  alias Klaxon.Profiles.Profile
  alias Atomex.Feed
  alias Atomex.Entry

  action_fallback KlaxonWeb.FallbackController

  def index(conn, _params) do
    with {:ok, %Profile{} = profile} <- current_profile(conn),
         {:ok, posts} <-
           Contents.get_posts(profile.uri, conn.assigns[:current_user], limit: 20) do
      feed = build_feed(conn, profile, posts)

      conn
      |> put_resp_content_type("text/xml")
      |> send_resp(200, feed)
    end
  end

  defp build_feed(conn, %Profile{} = profile, posts) do
    Feed.new(
      Routes.profile_url(conn, :index),
      DateTime.utc_now(),
      profile.display_name || profile.name
    )
    |> Feed.author(profile.display_name || profile.name, email: profile.url || profile.uri)
    |> Feed.link(Routes.rss_url(conn, :index), rel: "self")
    |> Feed.entries(Enum.map(posts, &get_entry(conn, profile, &1)))
    |> Feed.build()
    |> Atomex.generate_document()
  end

  defp get_entry(conn, %Profile{} = profile, %Post{} = post) do
    Entry.new(
      Routes.post_url(conn, :show, post.id),
      DateTime.from_naive!(post.published_at, "Etc/UTC"),
      snippet(post)
    )
    |> Entry.link(Routes.post_url(conn, :show, post.id))
    |> Entry.author(profile.display_name || profile.name)
    |> Entry.build()
  end
end
