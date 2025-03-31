defmodule KlaxonWeb.Api.TraceController do
  use KlaxonWeb, :controller
  alias Klaxon.Traces
  alias Klaxon.Traces.Processor
  alias Klaxon.Traces.Trace

  action_fallback KlaxonWeb.FallbackController

  @spec index(Plug.Conn.t(), any()) :: {:error, :not_found} | Plug.Conn.t()
  def index(conn, _params) do
    with {:ok, traces} <- Traces.get_traces_admin() do
      conn |> json(for trace <- traces, do: trace_map(trace))
    end
  end

  @spec show(any(), map()) :: {:error, :not_found} | Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with {:ok, %Trace{} = trace} <- Traces.get_trace_admin(id) do
      conn |> json(trace_map(trace))
    end
  end

  def reprocess(conn, %{"id" => id}) do
    with {:ok, %Trace{id: id, status: :raw}} <- Traces.get_trace_admin(id) do
      case Processor.reprocess_trace_by_id(id) do
        {:ok, _} ->
          conn |> json(%{message: "Trace reprocessed successfully"})
      end
    else
      {:ok, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Trace is not in a state to be reprocessed"})
    end
  end

  defp trace_map(trace) do
    %{
      id: trace.id,
      name: trace.name,
      status: trace.status,
      visibility: trace.visibility,
      inserted_at: trace.inserted_at,
      updated_at: trace.updated_at,
      time: trace.time
    }
  end
end
