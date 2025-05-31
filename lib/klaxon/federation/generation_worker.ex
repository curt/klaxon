defmodule Klaxon.Federation.GenerationWorker do
  require Logger
  alias Klaxon.Activities
  use Oban.Worker

  @impl Oban.Worker
  def perform(%{
        args:
          %{"actor" => actor, "object" => object, "action" => action, "follower" => follower} =
            args
      }) do
    Logger.info("Perform distribution: #{inspect(args)}")
    Activities.send_object(actor, object, action, follower)
    :ok
  end

  @impl Oban.Worker
  def perform(%{args: %{"actor" => actor, "object" => object, "action" => action} = args}) do
    Logger.info("Generate distribution workers: #{inspect(args)}")

    for follower <- Klaxon.Federation.get_follower_uris(actor) do
      %{actor: actor, object: object, action: action, follower: follower}
      |> Klaxon.Federation.GenerationWorker.new(max_attempts: 3)
      |> Oban.insert()
    end

    :ok
  end

  @impl Oban.Worker
  def perform(args) do
    Logger.warning("no matching args in worker: #{inspect(args)}")
    {:cancel, "no matching args in worker: #{inspect(args)}"}
  end
end
