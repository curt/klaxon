defmodule Klaxon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Klaxon.Repo,
      # Start the Telemetry supervisor
      KlaxonWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Klaxon.PubSub},
      # Start the Endpoint (http/https)
      KlaxonWeb.Endpoint,
      # Start a worker by calling: Klaxon.Worker.start_link(arg)
      # {Klaxon.Worker, arg}

      # Not included with Phoenix:
      # Start the Oban child
      {Oban, Application.fetch_env!(:klaxon, Oban)},
      # Start the Cachex caches
      {Cachex, name: :local_profile_cache, limit: 20}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Klaxon.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KlaxonWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
