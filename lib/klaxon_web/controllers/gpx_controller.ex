defmodule KlaxonWeb.GpxController do
  use KlaxonWeb, :controller
  alias Klaxon.Traces

  def index(conn, _params) do
    case Traces.render_traces_as_gpx(&Routes.trace_url(conn, :show, &1)) do
      {:ok, gpx} ->
        conn
        |> put_resp_content_type("application/gpx+xml")
        |> send_resp(200, gpx)

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Trace not found"})
    end
  end

  def show(conn, %{"id" => id}) do
    case Traces.render_trace_as_gpx(id, &Routes.trace_url(conn, :show, &1)) do
      {:ok, gpx} ->
        conn
        |> put_resp_content_type("application/gpx+xml")
        |> send_resp(200, gpx)

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Trace not found"})
    end
  end
end
