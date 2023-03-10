defmodule KlaxonWeb.ProfileView do
  use KlaxonWeb, :view

  def render("index.activity+json", %{
        conn: %Plug.Conn{assigns: %{current_endpoint: endpoint}} = _conn,
        profile: %Klaxon.Profiles.Profile{} = profile
      }) do
    public_key =
      case profile.public_key do
        key when is_binary(key) ->
          %{
            id: "#{profile.uri}#key",
            owner: profile.uri,
            publicKeyPem: profile.public_key
          }

        _ ->
          nil
      end

    contextify()
    |> Map.put("id", profile.uri)
    |> Map.put("type", "Person")
    |> Map.put("url", profile.uri)
    |> Map.put("preferredUsername", profile.name)
    |> Map.put("name", profile.display_name)
    |> Map.put("summary", profile.summary)
    |> Map.put("following", Routes.following_url(endpoint, :index))
    |> Map.put("followers", Routes.followers_url(endpoint, :index))
    |> Map.put("inbox", Routes.inbox_url(endpoint, :index))
    |> Map.put("outbox", Routes.outbox_url(endpoint, :index))
    |> Map.put("publicKey", public_key)
  end
end
