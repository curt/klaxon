defmodule KlaxonWeb.PongController do
  use KlaxonWeb, :controller

  alias Klaxon.Activities
  alias Klaxon.Profiles.Profile

  action_fallback KlaxonWeb.FallbackController

  def index(conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, pongs} <- Activities.get_pongs(profile.uri) do
      render(conn, "index.html", pongs: pongs)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, pong} <- Activities.get_pong(profile.uri, id) do
      render(conn, "show.html", pong: pong)
    end
  end

  defp current_profile(conn) do
    case conn.assigns[:current_profile] do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end
end
