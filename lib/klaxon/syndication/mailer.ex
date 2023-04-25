defmodule Klaxon.Syndication.Mailer do
  require Logger
  use Oban.Worker
  alias Klaxon.Syndication
  alias Klaxon.Syndication.Subscription

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id} = args}) do
    with {:ok, subscriber} <- Syndication.get_subscriber(id),
         {:ok, posts} <- Syndication.get_posts_for_subscriber(subscriber) do
      if length(posts) > 0 do
        {:ok, _email} = Syndication.send_digest_to_subscriber(subscriber, posts)
        {:ok, _subscriber} = Syndication.update_subscriber_from_posts(%Subscription{} = subscriber, posts)
      end
      :ok
    else
      _ ->
        Logger.warn("subscription not found: #{inspect(args)}")
        {:cancel, "subscription not found: #{inspect(args)}"}
    end
  end

  @impl Oban.Worker
  def perform(args) do
    Logger.warn("no matching args in worker: #{inspect(args)}")
    {:cancel, "no matching args in worker: #{inspect(args)}"}
  end
end
