defmodule Klaxon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger
  use Application

  @impl true
  def start(_type, _args) do
    log_version()

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

      # Start the Oban instance
      {Oban, Application.fetch_env!(:klaxon, Oban)},

      # Start the Cachex caches
      cachex_child("local_profile", limit: 20),
      cachex_child("get_profile", limit: 1000),
      cachex_child("fetch_profile", limit: 1000),
      cachex_child("get_post", limit: 1000),
      cachex_child("fetch_post", limit: 1000)
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

  defp cachex_child(name, opts) do
    %{
      id: "cachex_#{name}",
      start: {Cachex, :start_link, [String.to_atom("#{name}_cache"), opts]},
      type: :worker
    }
  end

  defp log_version do
    version = to_string(Application.spec(:klaxon, :vsn))
    Logger.info("Starting Klaxon version #{version}")
  end
end
