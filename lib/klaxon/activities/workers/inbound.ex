defmodule Klaxon.Activities.Workers.Inbound do
  require Logger
  use Oban.Worker

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "headers" => _headers,
            "requested_at" => _requested_at,
            "activity" => _activity
          } = args
      }) do
    Klaxon.Activities.Inbound.process(args)
  end

  @impl Oban.Worker
  def perform(args) do
    Logger.warn("bad args in worker: #{inspect(args)}")
    {:cancel, "no matching args pattern: #{inspect(args)}"}
  end
end
