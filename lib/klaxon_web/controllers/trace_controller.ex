defmodule KlaxonWeb.TraceController do
  use KlaxonWeb, :controller

  alias Klaxon.Contents
  alias Klaxon.Traces
  alias Klaxon.Traces.Trace
  alias KlaxonWeb.GeoJson

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
      changeset = Trace.changeset(%Trace{post: post})
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

  def geo(conn, %{"post_id" => post_id, "id" => id} = _params) do
    with {:ok, profile} <- current_profile(conn),
         {:ok, post} <-
           Contents.get_post(profile.uri, post_id, conn.assigns[:current_user]),
         {:ok, trace} <- Traces.get_trace_for_post(post, id) do
      points_features =
        Enum.map(trace.waypoints, fn x ->
          GeoJson.feature(GeoJson.point([x.lat, x.lon]))
        end)

      segments_features =
        Enum.map(
          Enum.flat_map(trace.tracks, fn x -> x.segments end),
          fn x ->
            GeoJson.feature(
              GeoJson.line_string(Enum.map(x.trackpoints, fn y -> [y.lat, y.lon] end))
            )
          end
        )

      json(conn, GeoJson.feature_collection(points_features ++ segments_features))
    end
  end
end
