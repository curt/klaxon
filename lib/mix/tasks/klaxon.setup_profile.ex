defmodule Mix.Tasks.Klaxon.SetupProfile do
  use Mix.Task

  @shortdoc "Bootstraps the first local profile"

  @moduledoc """
  Creates a local profile owned by an existing user.

  Non-interactive usage:

      mix klaxon.setup_profile --email you@example.com --name you --uri http://localhost:4000/

  Options:
  - `--email` (required): Email of an existing user.
  - `--name`  (required): Local username (preferredUsername).
  - `--uri`   (optional): Full profile URI. Defaults from Endpoint config.
  - `--force` (optional): Proceed even if a profile already exists at URI (will fail on unique constraint).
  """

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")

    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [email: :string, name: :string, uri: :string, force: :boolean],
        aliases: [e: :email, n: :name, u: :uri, f: :force]
      )

    email = opts[:email] || prompt_required("Email of existing user: ")
    name = opts[:name] || prompt_required("Local username (preferredUsername): ")
    uri = opts[:uri] || default_uri() || prompt_required("Profile URI (e.g. http://localhost:4000/): ")

    user = Klaxon.Auth.get_user_by_email(email)

    unless user do
      Mix.raise("No user found for email: #{email}")
    end

    case Klaxon.Profiles.get_profile_by_uri(uri) do
      {:ok, _profile} ->
        if opts[:force] do
          Mix.shell().info([:yellow, "A profile already exists at #{uri}. Continuing due to --force."])
        else
          Mix.raise("A profile already exists at #{uri}. Re-run with --force to attempt anyway.")
        end

      _ -> :ok
    end

    attrs = %{name: name, uri: uri}

    case Klaxon.Profiles.create_local_profile(attrs, user.id) do
      {:ok, profile} ->
        Mix.shell().info([:green, "Created local profile at ", :reset, profile.uri])
      {:error, %Ecto.Changeset{} = changeset} ->
        Mix.raise("Failed to create profile: #{inspect(changeset.errors)}")
      other ->
        Mix.raise("Unexpected result: #{inspect(other)}")
    end
  end

  defp prompt_required(prompt) do
    case IO.gets(prompt) do
      :eof -> Mix.raise("Input aborted")
      {:error, _reason} -> Mix.raise("Input aborted")
      str ->
        value = str |> to_string() |> String.trim()
        if value == "", do: Mix.raise("Value required"), else: value
    end
  end

  defp default_uri do
    endpoint = Application.get_env(:klaxon, KlaxonWeb.Endpoint, [])
    url = Keyword.get(endpoint, :url, [])
    host = url[:host] || System.get_env("PHX_HOST") || "localhost"
    scheme = url[:scheme] || (if host == "localhost", do: "http", else: "https")
    port = url[:port]

    base =
      case port do
        nil -> "#{scheme}://#{host}/"
        80 when scheme == "http" -> "http://#{host}/"
        443 when scheme == "https" -> "https://#{host}/"
        _ -> "#{scheme}://#{host}:#{port}/"
      end

    base
  end
end
