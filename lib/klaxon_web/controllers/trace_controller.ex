defmodule KlaxonWeb.TraceController do
  use KlaxonWeb, :controller

  alias Klaxon.Contents
  alias Klaxon.Traces
  alias Klaxon.Traces.Trace

  action_fallback(KlaxonWeb.FallbackController)

  def index(conn, %{"post_id" => post_id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, post_id, conn.assigns[:current_user]) do
      render(conn, post: post)
    end
  end

  def new(conn, %{"post_id" => post_id}) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, post_id, conn.assigns[:current_user]) do
      changeset = Trace.changeset(%Trace{})
      render(conn, "new.html", changeset: changeset, post: post)
    end
  end

  def create(conn, %{
        "post_id" => post_id,
        "trace" => %{"upload" => %Plug.Upload{path: path}} = trace_params
      }) do
    with {:ok, _post} <-
           Traces.import_trace(
             path,
             Map.put(trace_params, "post_id", post_id)
           ) do
      conn
      |> put_flash(:info, "Trace created successfully.")
      |> redirect(to: Routes.trace_path(conn, :index, post_id))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def show(conn, %{"id" => id}) do
    case Traces.get_trace(id) do
      {:ok, trace} ->
        render(conn, "show.html", trace: trace)
    end
  end
end
