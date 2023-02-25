defmodule KlaxonWeb.InboxView do
  use KlaxonWeb, :view

  def render("index.activity+json", %{conn: %Plug.Conn{} = conn}) do
    contextify()
    |> Map.put("id", Plug.Conn.request_url(conn))
    |> Map.put("type", "OrderedCollection")
    |> Map.put("orderedItems", [])
    |> Map.put("totalItems", 0)
  end
end
