defmodule KlaxonWeb.ProfileController do
  use KlaxonWeb, :controller
  import KlaxonWeb.Plugs
  import KlaxonWeb.Titles
  alias Klaxon.Profiles
  alias Klaxon.Profiles.Profile

  action_fallback KlaxonWeb.FallbackController
  plug :require_principal when action not in [:index]
  plug :activity_json_response

  def index(%Plug.Conn{private: %{:phoenix_format => "activity+json"}} = conn, _params) do
    with {:ok, profile} <- get_profile(conn) do
      render(conn, :index, profile: profile)
    end
  end

  def index(conn, _params) do
    with {:ok, profile} <- get_profile(conn) do
      render(conn, :index, profile: profile, title: title(profile))
    else
      _ -> {:error, :no_profile}
    end
  end

  def edit(conn, _params) do
    with {:ok, profile} <- get_profile(conn) do
      changeset = Profiles.change_profile(profile)
      render(conn, "edit.html", profile: profile, title: title(profile), changeset: changeset)
    end
  end

  def update(conn, %{"profile" => profile_params} = _params) do
    with {:ok, profile} <- get_profile(conn) do
      case Profiles.update_profile(profile, profile_params) do
        {:ok, _profile} ->
          conn
          |> put_flash(:info, "Profile updated successfully.")
          |> redirect(to: Routes.profile_path(conn, :index))

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, "edit.html", profile: profile, title: title(profile), changeset: changeset)
      end
    end
  end

  defp get_profile(conn) do
    case conn.assigns[:current_profile] do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end
end
