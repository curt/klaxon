defmodule Klaxon.HttpClient do
  use Tesla

  plug Tesla.Middleware.Headers, [{"accept", "application/activity+json, application/ld+json"}]
  plug Tesla.Middleware.JSON, decode_content_types: ["application/activity+json", "application/ld+json"]
  plug Tesla.Middleware.FollowRedirects, max_redirects: 2
  plug Tesla.Middleware.Logger, debug: false
  plug Klaxon.Middleware.Sign
end
