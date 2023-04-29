defmodule KlaxonWeb.SubscriptionView do
  use KlaxonWeb, :view

  @schedule_keywords [hourly: "Hourly", daily: "Daily", weekly: "Weekly", none: "Suspend"]

  defp schedule_options() do
    Enum.map(Ecto.Enum.values(Klaxon.Syndication.Subscription, :schedule), fn x ->
      {@schedule_keywords[x], x}
    end)
  end
end
