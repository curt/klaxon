defmodule KlaxonWeb.FollowersView do
  use KlaxonWeb, :view

  def render("index.activity+json", %{conn: %Plug.Conn{} = conn, followers: followers})
      when is_list(followers) do
    contextify()
    |> Map.put("id", Plug.Conn.request_url(conn))
    |> Map.put("type", "Collection")
    |> Map.put("items", followers)
    |> Map.put("totalItems", length(followers))
  end
end
