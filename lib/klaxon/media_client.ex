defmodule Klaxon.MediaClient do
  use Tesla

  plug Tesla.Middleware.FollowRedirects, max_redirects: 2
  plug Tesla.Middleware.Logger, debug: false
end
