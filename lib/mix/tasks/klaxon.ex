defmodule Mix.Tasks.Klaxon do
  use Mix.Task

  @shortdoc "Klaxon tasks help"

  @moduledoc """
  Lists available `klaxon.*` Mix tasks.

      mix klaxon
      mix klaxon help

  To see detailed help for a specific task, run:

      mix help klaxon.setup_profile
  """

  @impl true
  def run(_argv) do
    print_help()
  end

  defp print_help do
    Mix.shell().info("Klaxon tasks:")

    tasks = discover_tasks()

    if tasks == [] do
      Mix.shell().info("  (no klaxon.* tasks found)")
    else
      Enum.each(tasks, fn {name, mod} ->
        short = Mix.Task.shortdoc(mod) || ""
        Mix.shell().info("  mix #{name}\t# #{short}")
      end)
    end
  end

  defp discover_tasks do
    Mix.Task.load_all()

    Mix.Task.all_modules()
    |> Enum.filter(fn mod ->
      # Include Mix.Tasks.Klaxon.* but exclude this help task itself unless it is a subtask
      parts = Module.split(mod)
      parts |> Enum.take(3) == ["Elixir", "Mix", "Tasks"] and Enum.at(parts, 3) == "Klaxon"
    end)
    |> Enum.map(&{module_to_task_name(&1), &1})
    |> Enum.filter(fn {name, _} -> String.starts_with?(name, "klaxon.") end)
    |> Enum.sort_by(fn {name, _} -> name end)
  end

  defp module_to_task_name(mod) do
    ["Elixir", "Mix", "Tasks" | rest] = Module.split(mod)
    rest
    |> Enum.map(&Macro.underscore/1)
    |> Enum.join(".")
  end
end
