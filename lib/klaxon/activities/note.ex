defmodule Klaxon.Activities.Note do
  alias Klaxon.Contents.Post
  import Klaxon.Activities.Helpers

  def note(%Post{} = post, routes, endpoint) do
    %{}
    |> Map.put("type", "Note")
    |> Map.put("id", post.uri)
    |> Map.put("attributedTo", post.profile.uri)
    |> Map.put("context", post.context_uri)
    |> Map.put("conversation", post.context_uri)
    |> Map.put("content", post.content_html)
    |> Map.put("published", stampify(post.published_at))
    |> Map.put("url", post.uri)
    |> mergify("inReplyTo", post.in_reply_to_uri)
    |> mergify("to", to(post, routes, endpoint))
    |> mergify("cc", cc(post, routes, endpoint))
    |> mergify("attachment", attachments(post, routes, endpoint))
  end

  defp attachments(%{attachments: attachments}, routes, endpoint) do
    for attachment <- attachments do
      attachment(attachment, routes, endpoint)
    end
  end

  defp attachment(%{media: media} = attachment, routes, endpoint) do
    %{
      "mediaType" => media.mime_type,
      "name" => snippet(attachment),
      "summary" => htmlify(attachment),
      "type" => "Document",
      "url" => routes.media_url(endpoint, :show, :post, :full, media.id)
    }
  end

  defp to(_post, _routes, _endpoint),
    do: ["https://www.w3.org/ns/activitystreams#Public"]

  defp cc(_post, routes, endpoint), do: [routes.followers_url(endpoint, :index)]
end
