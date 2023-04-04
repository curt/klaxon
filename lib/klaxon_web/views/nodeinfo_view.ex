defmodule KlaxonWeb.NodeInfoView do
  use KlaxonWeb, :view

  def render("well_known.json", %{conn: conn}) do
    %{
      links: [
        %{
          href: Routes.node_info_url(conn, :version, "2.0"),
          rel: "http://nodeinfo.diaspora.software/ns/schema/2.0"
        }
      ]
    }
  end

  def render("version.json", %{version: "2.0"}) do
    %{
      version: "2.0",
      software: %{
        name: "Klaxon",
        version: "pre-alpha"
      },
      protocols: ["activitypub"],
      services: %{inbound: [], outbound: ["rss2.0"]},
      openRegistrations: false
    }
  end
end
