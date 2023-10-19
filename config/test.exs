import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :klaxon, Klaxon.Repo,
  username: "postgres",
  password: "my_password",
  hostname: "localhost",
  database: "klaxon_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: 54320,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :klaxon, KlaxonWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "rNnEXbW98G2IY+V+wqKyI9vwHHAdHyGzvZrRHnvEgTTw7fBQ31ffRjx+rJHy/T7L",
  server: false

# In test we don't send emails.
config :klaxon, Klaxon.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Inline tests for Oban
config :klaxon, Oban, testing: :inline
