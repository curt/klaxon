defmodule KlaxonWeb.PostView do
  use KlaxonWeb, :view
  alias Klaxon.Contents.Post
  alias Klaxon.Snippet

  def render("show.activity+json", %{
        conn: conn,
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
    |> mergify("to", post_to(conn, post))
    |> mergify("cc", post_cc(conn, post))
  end

  def status_action(%Post{} = post) do
    case post.status do
      :draft -> "drafted"
      :published -> "posted"
      _ -> "appeared"
    end
  end

  def status_date(%Post{} = post) do
    case post.status do
      :published -> post.published_at || post.inserted_at
      _ -> post.inserted_at
    end
  end

  def snippet(%Post{} = post) do
    post.title || Snippet.snippify(post.source || post.content_html || captions(post) || "", 140)
  end

  defp captions(%Post{} = post) do
    if post.attachments do
      Enum.reduce(post.attachments, "", fn x, acc -> acc <> "\n\n" <> (x.caption || "") end)
    end
  end

  defp post_to(_conn, _post), do: ["https://www.w3.org/ns/activitystreams#Public"]
  defp post_cc(conn, _post), do: [Routes.followers_url(conn, :index)]
end
