defmodule Klaxon.Activities.Note do
  alias Klaxon.Contents.Post
  import Klaxon.Activities.Helpers

  def note(%Post{} = post) do
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
    |> mergify("to", to())
    |> mergify("cc", cc(post.profile.uri))
    |> mergify("attachment", attachments(post))
  end

  defp attachments(%{attachments: attachments}) do
    for attachment <- attachments do
      attachment(attachment)
    end
  end

  defp attachment(%{media: media} = attachment) do
    %{
      "mediaType" => media.mime_type,
      "name" => snippet(attachment),
      "summary" => htmlify(attachment),
      "type" => "Document",
      # FIXME! Heinous kludge. We should store URIs for impressions.
      "url" => String.replace(media.uri, "/raw/", "/full/")
    }
  end

  defp to(), do: ["https://www.w3.org/ns/activitystreams#Public"]

  defp cc(profile_uri), do: ["#{profile_uri}followers"]
end
