defmodule KlaxonWeb.NodeInfoView do
  use KlaxonWeb, :view

  def render("well_known.json", _assigns) do
    %{
      links: [
        %{
          href: Routes.node_info_url(KlaxonWeb.Endpoint, :version, "2.0"),
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
      openRegistrations: false,
    }
  end
end
