defmodule KlaxonWeb.PostView do
  use KlaxonWeb, :view
  import KlaxonWeb.Titles
  alias Klaxon.Contents.Post

  def render("show.activity+json", %{
        conn: %{assigns: %{current_endpoint: endpoint}} = _conn,
        post: %Post{} = post
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
    |> mergify("inReplyTo", post.in_reply_to_uri)
    |> mergify("to", post_to(endpoint, post))
    |> mergify("cc", post_cc(endpoint, post))
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

  defp post_to(_endpoint, _post), do: ["https://www.w3.org/ns/activitystreams#Public"]
  defp post_cc(endpoint, _post), do: [Routes.followers_url(endpoint, :index)]
end
