defmodule Klaxon.Activities.Inbox.Worker do
  require Logger
  use Oban.Worker
  alias Klaxon.Activities.Inbox.Async

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "headers" => _headers,
            "requested_at" => _requested_at,
            "activity" => _activity
          } = args
      }) do
    Async.process(args)
  end

  @impl Oban.Worker
  def perform(args) do
    Logger.warning("bad args in worker: #{inspect(args)}")
    {:cancel, "no matching args pattern: #{inspect(args)}"}
  end
end
