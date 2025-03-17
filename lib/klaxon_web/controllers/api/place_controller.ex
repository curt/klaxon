defmodule KlaxonWeb.Api.PlaceController do
  use KlaxonWeb, :controller
  alias Klaxon.Contents
  alias Klaxon.Contents.Place

  action_fallback KlaxonWeb.FallbackController

  @spec index(Plug.Conn.t(), any()) :: {:error, :not_found} | Plug.Conn.t()
  def index(conn, _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, places} <- Contents.get_places(profile.uri, conn.assigns.current_user) do
      conn |> json(places)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, %Place{} = place} <- Contents.get_place(profile.uri, id, conn.assigns.current_user) do
      conn |> json(place)
    end
  end

  def create(conn, %{"place" => place_params}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, %Place{} = place} <- Contents.create_place(profile, place_params) do
      conn
      |> put_status(:created)
      |> json(place)
    end
  end

  def update(conn, %{"id" => id, "place" => place_params}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, %Place{} = place} <-
           Contents.get_place(profile.uri, id, conn.assigns.current_user),
         {:ok, %Place{} = updated_place} <- Contents.update_place(profile, place, place_params) do
      conn |> json(updated_place)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, %Place{} = place} <-
           Contents.get_place(profile.uri, id, conn.assigns.current_user),
         {:ok, %Place{} = _} <- Contents.delete_place(profile, place) do
      send_resp(conn, :no_content, "")
    end
  end
end
