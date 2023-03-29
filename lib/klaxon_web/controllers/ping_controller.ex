defmodule KlaxonWeb.PingController do
  use KlaxonWeb, :controller
  import KlaxonWeb.Plugs

  alias Klaxon.Activities
  alias Klaxon.Activities.Ping
  alias Klaxon.Profiles.Profile

  action_fallback KlaxonWeb.FallbackController
  plug :require_principal

  def index(conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, pings} <- Activities.get_pings(profile.uri) do
      render(conn, "index.html", pings: pings)
    end
  end

  def new(conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         changeset <- Activities.change_ping(profile.uri, %Ping{}) do
      render(conn, "new.html", changeset: changeset)
    end
  end

  # def create(conn, %{"ping" => ping_params}) do
  #   case Activities.create_ping(ping_params) do
  #     {:ok, ping} ->
  #       conn
  #       |> put_flash(:info, "Ping created successfully.")
  #       |> redirect(to: Routes.ping_path(conn, :show, ping))

  #     {:error, %Ecto.Changeset{} = changeset} ->
  #       render(conn, "new.html", changeset: changeset)
  #   end
  # end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, ping} <- Activities.get_ping(profile.uri, id) do
      render(conn, "show.html", ping: ping)
    end
  end

  # def edit(conn, %{"id" => id}) do
  #   ping = Activities.get_ping!(id)
  #   changeset = Activities.change_ping(ping)
  #   render(conn, "edit.html", ping: ping, changeset: changeset)
  # end

  # def update(conn, %{"id" => id, "ping" => ping_params}) do
  #   ping = Activities.get_ping!(id)

  #   case Activities.update_ping(ping, ping_params) do
  #     {:ok, ping} ->
  #       conn
  #       |> put_flash(:info, "Ping updated successfully.")
  #       |> redirect(to: Routes.ping_path(conn, :show, ping))

  #     {:error, %Ecto.Changeset{} = changeset} ->
  #       render(conn, "edit.html", ping: ping, changeset: changeset)
  #   end
  # end

  # def delete(conn, %{"id" => id}) do
  #   ping = Activities.get_ping!(id)
  #   {:ok, _ping} = Activities.delete_ping(ping)

  #   conn
  #   |> put_flash(:info, "Ping deleted successfully.")
  #   |> redirect(to: Routes.ping_path(conn, :index))
  # end

  defp current_profile(conn) do
    case conn.assigns[:current_profile] do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end
end
