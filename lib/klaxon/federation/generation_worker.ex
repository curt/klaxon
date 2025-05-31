defmodule Klaxon.Federation.GenerationWorker do
  require Logger
  alias Klaxon.Activities
  use Oban.Worker

  @impl Oban.Worker
  def perform(%{args: %{"action" => action, "id" => id, "uri" => uri, "type" => "post"}}) do
    Logger.info("Perform distribution: post #{id} action #{action} uri: #{uri}")
    Activities.send_post(id, uri, action)
    :ok
  end

  @impl Oban.Worker
  def perform(%{args: %{"action" => action, "id" => id, "type" => "post"}}) do
    Logger.info("Generate distribution workers for post: #{id} with action: #{action}")

    for uri <- Klaxon.Federation.get_follower_uris_for_post(id) do
      %{type: :post, id: id, action: action, uri: uri}
      |> Klaxon.Federation.GenerationWorker.new()
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
