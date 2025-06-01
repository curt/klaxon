defmodule KlaxonWeb.PostView do
  use KlaxonWeb, :view
  alias Klaxon.Activities.Note
  alias Klaxon.Activities.Helpers
  alias Klaxon.Contents.Post

  def render("show.activity+json", %{
        conn: conn,
        post: %Post{} = post
      }) do
    Note.note(post, Routes, conn)
    |> Helpers.contextify()
  end

  @spec status_action(%Post{:status => any}) :: String.t()
  def status_action(%Post{} = post) do
    case post.status do
      :draft -> "drafted"
      :published -> "posted"
      _ -> "appeared"
    end
  end

  @spec status_date(%Post{:status => any}) :: any
  def status_date(%Post{} = post) do
    case post.status do
      :published -> post.published_at || post.inserted_at
      _ -> post.inserted_at
    end
  end
end
