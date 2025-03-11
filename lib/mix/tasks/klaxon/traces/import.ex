defmodule Mix.Tasks.Klaxon.Traces.Import do
  use Mix.Task
  alias Klaxon.Traces

  @moduledoc """
  A Mix task to import all `.gpx` files from a specified folder.

  ## Usage

      mix klaxon.traces.import /path/to/folder profile_id

  This task will iterate over all `.gpx` files in the specified folder and call the
  `import_trace` function for each file, associating each trace with the given profile ID.

  ## Example

  Assuming you have a folder `./.local/` containing `.gpx` files and you want
  to associate them with a profile ID of `CM2DgoNgqeH18NQy37g9s`, you would run:

    mix klaxon.traces.import ./.local/ CM2DgoNgqeH18NQy37g9s

  This will import all `.gpx` files in the specified folder and associate them
  with the profile ID `CM2DgoNgqeH18NQy37g9s`.
  """

  @shortdoc "Imports all .gpx files from the specified folder"
  def run([folder_path, profile_id]) do
    Mix.Task.run("app.start")

    folder_path
    |> Path.expand()
    |> Path.join("*.gpx")
    |> Path.wildcard()
    |> Enum.each(&import_trace(&1, profile_id))
  end

  defp import_trace(file_path, profile_id) do
    # Get the filename without the extension
    name = Path.basename(file_path, ".gpx")

    # Add any necessary attributes here
    attrs = %{name: name, profile_id: profile_id}

    case Traces.import_trace(file_path, attrs) do
      {:ok, _trace} -> IO.puts("Successfully imported #{file_path}")
      {:error, reason} -> IO.puts("Failed to import #{file_path}: #{reason}")
    end
  end
end
