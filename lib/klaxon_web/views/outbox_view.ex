defmodule KlaxonWeb.OutboxView do
  use KlaxonWeb, :view

  def render("index.activity+json", %{conn: %Plug.Conn{} = conn, posts: posts}) do
    items =
      for post <- posts do
        post
        |> Klaxon.Activities.Note.note()
        |> Klaxon.Activities.Helpers.activify("create")
      end

    contextify()
    |> Map.put("id", Plug.Conn.request_url(conn))
    |> Map.put("type", "OrderedCollection")
    |> Map.put("orderedItems", items)
    |> Map.put("totalItems", length(items))
  end
end
