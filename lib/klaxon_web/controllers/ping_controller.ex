defmodule KlaxonWeb.PingController do
  use KlaxonWeb, :controller

  alias Klaxon.Activities

  action_fallback KlaxonWeb.FallbackController

  def index(conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, pings} <- Activities.get_pings(profile.uri) do
      render(conn, "index.html", pings: pings)
    end
  end

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"ping" => ping_params}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, _ping} <- Activities.send_ping(profile.uri, ping_params["to"]) do
      conn
      |> put_flash(:info, "Ping created successfully.")
      |> redirect(to: Routes.ping_path(conn, :index))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, ping} <- Activities.get_ping(profile.uri, id) do
      render(conn, "show.html", ping: ping)
    end
  end
end
