defmodule Klaxon.Syndication.Scheduler do
  require Logger
  use Oban.Worker
  alias Klaxon.Syndication

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"schedule" => schedule} = args}) do
    schedule = String.to_atom(schedule)
    case Syndication.get_subscribers(schedule) do
      {:ok, subscribers} ->
        for subscriber <- subscribers do
          %{id: subscriber.id}
          |> Syndication.Mailer.new()
          |> Oban.insert()
        end
        :ok
      _ ->
        Logger.warn("no subscriptions found: #{inspect(args)}")
        {:cancel, "no subscriptions found: #{inspect(args)}"}
    end
  end

  @impl Oban.Worker
  def perform(args) do
    Logger.warn("no matching args in worker: #{inspect(args)}")
    {:cancel, "no matching args in worker: #{inspect(args)}"}
  end
end
