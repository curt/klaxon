defmodule KlaxonWeb.PostView do
  use KlaxonWeb, :view
  alias Klaxon.Contents.Post
  alias Klaxon.Contents.Attachment

  def render("show.activity+json", %{
        conn: conn,
        post: %Post{} = post
      }) do
    contextify()
    |> post(conn, post)
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

  @spec post(map, any, %Post{}) :: map
  def post(%{} = activity, conn, %Post{} = post) do
    activity
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
    |> mergify("attachment", post_attachments(conn, post))
  end

  @spec post_attachments(any, %Post{}) :: list
  def post_attachments(conn, %Post{} = post) do
    for attachment <- post.attachments do
      post_attachment(conn, attachment)
    end
  end

  @spec post_attachment(any, %Attachment{}) :: map
  def post_attachment(conn, %Attachment{} = attachment) do
    %{
      "mediaType" => attachment.media.mime_type,
      "summary" => attachment.caption,
      "type" => "Document",
      "url" => Routes.media_url(conn, :show, :post, :full, attachment.media.id)
    }
  end

  defp post_to(_conn, _post), do: ["https://www.w3.org/ns/activitystreams#Public"]
  defp post_cc(conn, _post), do: [Routes.followers_url(conn, :index)]
end
