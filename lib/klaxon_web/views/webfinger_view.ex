defmodule KlaxonWeb.WebfingerView do
  use KlaxonWeb, :view

  def render("show.json", %{webfinger: _profile, resource: resource}) do
    %{
      subject: resource,
      aliases: [
        Routes.profile_url(KlaxonWeb.Endpoint, :index)
      ],
      links: [
        %{
          rel: "self",
          type: "application/activity+json",
          href: Routes.profile_url(KlaxonWeb.Endpoint, :index)
        }
      ]
    }
  end
end
