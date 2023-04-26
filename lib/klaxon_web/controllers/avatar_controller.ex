defmodule KlaxonWeb.AvatarController do
  use KlaxonWeb, :controller

  alias Klaxon.Profiles
  alias Klaxon.Profiles.Profile

  action_fallback(KlaxonWeb.FallbackController)

  def new(conn, _params) do
    with {:ok, %Profile{} = _profile} <- current_profile(conn) do
      render(conn)
    end
  end

  def create(conn, %{"upload" => %Plug.Upload{path: path, content_type: content_type}} = _params) do
    with {:ok, %Profile{} = profile} <- current_profile(conn),
         {:ok, %Profile{} = _profile} <-
           Profiles.insert_local_profile_avatar(
             profile.id,
             path,
             content_type,
             &Routes.media_url(conn, :show, &1, &2, &3)
           ) do
      conn
      |> put_flash(:info, "Avatar changed successfully.")
      |> redirect(to: Routes.profile_path(conn, :edit))
    end
  end
end
