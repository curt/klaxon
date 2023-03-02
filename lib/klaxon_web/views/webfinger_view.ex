defmodule KlaxonWeb.WebfingerView do
  use KlaxonWeb, :view

  def render("show.json", %{webfinger: _profile, resource: resource} = assigns) do
    %{
      subject: resource,
      aliases: [
        Routes.profile_url(endpointify(assigns.current_profile.uri), :index)
      ],
      links: [
        %{
          rel: "self",
          type: "application/activity+json",
          href: Routes.profile_url(endpointify(assigns.current_profile.uri), :index)
        }
      ]
    }
  end
end
