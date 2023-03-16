defmodule KlaxonWeb.PostsView do
  use KlaxonWeb, :view
  import KlaxonWeb.Titles

  def render("show.activity+json", %{
    conn: %{assigns: %{current_endpoint: _endpoint}} = _conn,
    post: %Klaxon.Contents.Post{} = post
  }) do
    contextify()
    |> Map.put("type", "Note")
    |> Map.put("id", post.uri)
    |> Map.put("attributedTo", post.profile.uri)
    |> Map.put("context", post.context_uri)
    |> Map.put("conversation", post.context_uri)
    |> Map.put("content", post.content_html)
    |> Map.put("published", Timex.format!(post.published_at, "{RFC3339z}"))
    |> Map.put("url", post.uri)
  end

  def status_action(post) do
    case post.status do
      :draft -> "Drafted"
      :published -> "Posted"
      _ -> "Appeared"
    end
  end

  def status_date(post) do
    case post.status do
      :published -> post.published_at || post.inserted_at
      _ -> post.inserted_at
    end
  end
end
