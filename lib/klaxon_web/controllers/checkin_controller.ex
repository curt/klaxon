defmodule KlaxonWeb.CheckinController do
  use KlaxonWeb, :controller
  alias Klaxon.Checkins
  alias Klaxon.Contents
  action_fallback KlaxonWeb.FallbackController

  def index(conn, %{"place_id" => place_id}) do
    with {:ok, place} <-
           Contents.get_place(
             conn.assigns.current_profile.uri,
             place_id,
             conn.assigns.current_user
           ),
         {:ok, checkins} <-
           Checkins.get_checkins(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id
           ) do
      render(conn, "index.html", place: place, checkins: checkins)
    end
  end

  def show(conn, %{"place_id" => place_id, "id" => id}) do
    with {:ok, place} <-
           Contents.get_place(
             conn.assigns.current_profile.uri,
             place_id,
             conn.assigns.current_user
           ),
         {:ok, checkin} <-
           Checkins.get_checkin(
             conn.assigns.current_profile.uri,
             conn.assigns.current_user,
             place_id,
             id
           ) do
      render(conn, "show.html", place: place, checkin: checkin)
    end
  end
end
