defmodule KlaxonWeb.NodeInfoView do
  use KlaxonWeb, :view

  def render("well_known.json", %{conn: conn}) do
    %{
      links: [
        well_known_map(conn, "2.0"),
        well_known_map(conn, "2.1")
      ]
    }
  end

  def render("version.json", %{version: "2.0"}), do: version_map("2.0")

  def render("version.json", %{version: "2.1"}), do: version_map("2.1")

  defp well_known_map(conn, version) do
    %{
      href: Routes.node_info_url(conn, :version, version),
      rel: "http://nodeinfo.diaspora.software/ns/schema/#{version}"
    }
  end

  defp version_map(version) do
    %{
      version: version,
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
