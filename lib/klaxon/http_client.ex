defmodule Klaxon.HttpClient do
  def activity_client() do
    Tesla.client([
      {Tesla.Middleware.Headers, [{"accept", "application/activity+json, application/ld+json"}]},
      {Tesla.Middleware.JSON, decode_content_types: ["application/activity+json", "application/ld+json"]}
    ])
  end

  def activity_get(url) do
      activity_client()
      |> Tesla.get(url)
  end
end
