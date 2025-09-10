defmodule Klaxon.MixProject do
  use Mix.Project

  def project do
    [
      app: :klaxon,
      version: version(),
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  defp version do
    case File.read("VERSION.full") do
      {:ok, v} -> String.trim(v)
      _ -> "0.0.0+dev"
    end
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Klaxon.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.12"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.24"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},

      # not supplied with Phoenix
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:castore, "~> 1.0"},
      {:oban, "~> 2.19"},
      {:http_signatures, "~> 0.1.1"},
      {:tesla, "~> 1.14"},
      {:hackney, "~> 1.20"},
      {:cachex, "~> 3.6"},
      {:timex, "~> 3.7"},
      {:ecto_base58, git: "https://github.com/curt/ecto_base58.git"},
      {:x509, "~> 0.8.7"},
      {:earmark, "~> 1.4.47"},
      {:slugify, "~> 1.3"},
      {:mogrify, "~> 0.9.2"},
      {:excon, "~> 4.0"},
      {:gen_smtp, "~> 1.2"},
      {:waffle, "~> 1.1"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.1"},
      {:atomex, "~> 0.5.1"},
      {:mox, "~> 1.1", only: :test},
      {:haversine, "~> 0.1.0"},

      # Dependency of `:ex_aws`
      {:sweet_xml, "~> 0.6"},

      # kludge because otherwise these two excon dependencies don't end up in the release
      {:png, "~> 0.2"},
      {:blake2, "~> 1.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
