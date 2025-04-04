defmodule KlaxonWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :klaxon

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_klaxon_key",
    signing_salt: "qBEozXdL"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :klaxon,
    gzip: false,
    only: ~w(assets fonts klaxon images android-chrome-192x192.png
      android-chrome-512x512.png apple-touch-icon.png favicon.ico
      favicon-16x16.png favicon-32x32.png robots.txt site.webmanifest
      style.css)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :klaxon
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session, @session_options

  if Mix.env() == :test do
    plug Plug.Session,
      store: :cookie,
      key: "_klaxon_key",
      signing_salt: "some_salt"
  end

  plug KlaxonWeb.Router
end
