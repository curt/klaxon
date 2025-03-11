defmodule KlaxonWeb.GpxController do
  use KlaxonWeb, :controller
  alias Klaxon.Traces

  def show(conn, %{"id" => id}) do
    case Traces.render_trace_as_gpx(id) do
      {:ok, gpx} ->
        conn
        |> put_resp_content_type("application/gpx+xml")
        |> send_resp(200, gpx)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Trace not found"})
    end
  end
end
