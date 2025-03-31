defmodule KlaxonWeb.Api.WaypointController do
  use KlaxonWeb, :controller
  alias Klaxon.Traces

  action_fallback KlaxonWeb.FallbackController

  def index(conn, %{"trace_id" => trace_id}) do
    with {:ok, waypoints} <- Traces.get_waypoints_admin(trace_id) do
      conn |> json(for waypoint <- waypoints, do: waypoint_map(waypoint))
    end
  end

  defp waypoint_map(waypoint) do
    %{
      id: waypoint.id,
      name: waypoint.name,
      time: waypoint.time,
      lat: waypoint.lat,
      lon: waypoint.lon,
      ele: waypoint.ele
    }
  end
end
