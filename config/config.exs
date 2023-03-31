# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :klaxon,
  ecto_repos: [Klaxon.Repo],
  generators: [binary_id: true]

# Configures the endpoint
config :klaxon, KlaxonWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: KlaxonWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Klaxon.PubSub,
  live_view: [signing_salt: "fUo4/BbY"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :klaxon, Klaxon.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :mime, :types, %{
  "application/activity+json" => ["activity+json"],
  "application/ld+json" => ["activity+json"]
}

config :phoenix, :format_encoders,
  json: Jason,
  "activity+json": Jason

config :klaxon, Oban,
  repo: Klaxon.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

config :tesla, adapter: Tesla.Adapter.Hackney

config :tailwind, version: "3.2.7", default: [
  args: ~w(
    --config=tailwind.config.js
    --input=css/app.css
    --output=../priv/static/assets/app.css
  ),
  cd: Path.expand("../assets", __DIR__)
]

config :klaxon, :git, revision: elem(System.cmd("git", ["rev-parse", "HEAD"]), 0)

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
