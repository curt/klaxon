defmodule Klaxon.Traces do
  require Logger
  alias Klaxon.Repo
  alias Klaxon.Traces.Trace
  alias Klaxon.Traces.Track
  alias Klaxon.Traces.Segment
  alias Klaxon.Traces.Trackpoint
  alias Klaxon.Traces.Waypoint
  import Ecto.Query
  import SweetXml

  @spec get_traces() :: {:ok, list(Trace.t())} | {:error, any()}
  def get_traces do
    subquery =
      from(w in Waypoint,
        group_by: w.trace_id,
        select: %{trace_id: w.trace_id, min_created_at: min(w.time)}
      )

    query =
      from(t in Trace,
        join: w in subquery(subquery),
        on: t.id == w.trace_id,
        where: t.visibility == :public,
        # Ensure waypoints also preload their trace
        preload: [waypoints: [:trace]],
        order_by: w.min_created_at,
        select_merge: %{time: w.min_created_at}
      )

    case Repo.all(query) do
      [] ->
        {:ok, []}

      traces ->
        {:ok, traces}
    end
  end

  @doc """
  Fetches a trace by its ID.

  ## Parameters

    - id: The ID of the trace to fetch.

  ## Returns

    - `{:ok, %Trace{}}` if the trace is found.
    - `{:error, :not_found}` if the trace is not found.

  The trace is preloaded with its associated waypoints and tracks,
  where each track includes its segments and trackpoints.
  """
  @spec get_trace(binary()) :: {:ok, Trace.t()} | {:error, :not_found}
  def get_trace(id) do
    case from(t in Trace,
           where: t.id == ^id and t.visibility != :private,
           # Ensure waypoints also preload their trace
           preload: [waypoints: [:trace], tracks: [segments: :trackpoints]]
         )
         |> Repo.one() do
      %Trace{} = trace -> {:ok, trace}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Imports GPX traces from the specified folder path and associates them with the given profile ID.

  ## Parameters

    - folder_path: The path to the folder containing the trace files.
    - profile_id: The ID of the profile to associate the traces with.

  ## Examples

      iex> Klaxon.Traces.import_traces("/path/to/traces", "CM2DgoNgqeH18NQy37g9s")
      :ok

  """
  @spec import_traces(binary(), binary()) :: :ok
  def import_traces(folder_path, profile_id) do
    folder_path
    |> Path.expand()
    |> Path.join("*.gpx")
    |> Path.wildcard()
    |> Enum.each(&import_trace(&1, %{name: Path.basename(&1, ".gpx"), profile_id: profile_id}))

    :ok
  end

  @doc """
  Imports a GPX trace from the specified file path and attributes.

  ## Parameters

    - path: The file path from which to import the trace.
    - attrs: A map of attributes related to the trace.

  ## Examples

      iex> Klaxon.Traces.import_trace("/path/to/trace.gpx", %{profile_id: "CM2DgoNgqeH18NQy37g9s"})
      :ok

  """
  @spec import_trace(Path.t(), map()) :: :ok
  def import_trace(path, attrs) do
    doc =
      path
      |> File.stream!()
      |> parse()

    {:ok, trace} = insert_trace(attrs)

    waypoints = extract_waypoints(doc)
    tracks = extract_tracks(doc)

    import_waypoints(waypoints, trace.id)
    import_tracks(tracks, trace.id)

    :ok
  end

  defp extract_waypoints(doc) do
    xpath(doc, ~x"//wpt"el,
      name: ~x"./name/text()"s,
      lat: ~x"@lat"f,
      lon: ~x"@lon"f,
      ele: ~x"./ele/text()"f,
      time: ~x"./time/text()"s
    )
  end

  defp extract_tracks(doc) do
    xpath(doc, ~x"//trk"el,
      name: ~x"./name/text()"s,
      segments: [
        ~x"./trkseg"el,
        trackpoints: [
          ~x"./trkpt"el,
          lat: ~x"@lat"f,
          lon: ~x"@lon"f,
          ele: ~x"./ele/text()"f,
          time: ~x"./time/text()"s
        ]
      ]
    )
  end

  defp import_waypoints(waypoints, trace_id) do
    for waypoint <- waypoints do
      {:ok, time, 0} = DateTime.from_iso8601(waypoint.time)

      insert_waypoint(%{
        trace_id: trace_id,
        name: waypoint.name,
        lat: waypoint.lat,
        lon: waypoint.lon,
        ele: waypoint.ele,
        time: time
      })
    end
  end

  defp import_tracks(tracks, trace_id) do
    for track <- tracks do
      {:ok, inserted_track} = insert_track(%{trace_id: trace_id, name: track.name})

      for segment <- track.segments do
        {:ok, inserted_segment} = insert_segment(%{track_id: inserted_track.id})

        for trackpoint <- segment.trackpoints do
          {:ok, time, 0} = DateTime.from_iso8601(trackpoint.time)

          insert_trackpoint(%{
            segment_id: inserted_segment.id,
            lat: trackpoint.lat,
            lon: trackpoint.lon,
            ele: trackpoint.ele,
            time: time
          })
        end
      end
    end
  end

  defp insert_trace(attrs) do
    %Trace{}
    |> Trace.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_track(attrs) do
    %Track{}
    |> Track.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_segment(attrs) do
    %Segment{}
    |> Segment.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_trackpoint(attrs) do
    %Trackpoint{}
    |> Trackpoint.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_waypoint(attrs) do
    %Waypoint{}
    |> Waypoint.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_trace(Trace.t()) :: :ok
  def delete_trace(trace) do
    Repo.delete(trace)
  end

  @spec render_traces_as_gpx((binary() -> binary())) :: {:ok, binary()} | {:error, any()}
  def render_traces_as_gpx(url_fun) do
    with {:ok, traces} <- get_traces() do
      waypoints = Enum.flat_map(traces, fn trace -> trace.waypoints end)
      trace = %Trace{name: "Traces", waypoints: waypoints, tracks: []}
      render_trace_as_gpx(trace, url_fun)
    end
  end

  @spec render_trace_as_gpx(struct() | binary(), (binary() -> binary())) ::
          {:ok, binary()} | {:error, :not_found}
  def render_trace_as_gpx(%Trace{} = trace, url_fun) do
    gpx = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="Klaxon">
      <metadata>
        <name>#{trace.name}</name>
      </metadata>
      #{render_waypoints(trace.waypoints, url_fun)}
      #{render_tracks(trace.tracks)}
    </gpx>
    """

    {:ok, gpx}
  end

  def render_trace_as_gpx(trace_id, url_fun) do
    with {:ok, trace} <- get_trace(trace_id) do
      render_trace_as_gpx(trace, url_fun)
    end
  end

  defp render_waypoints(waypoints, url_fun) do
    Enum.map(waypoints, fn waypoint ->
      """
      <wpt lat="#{waypoint.lat}" lon="#{waypoint.lon}">
        <name>#{waypoint.name}</name>
        <desc>
          <![CDATA[
            <div class="title">#{waypoint.name}</div>
            <div class="subtitle"><a href="#{url_fun.(waypoint.trace.id)}">#{waypoint.trace.name}</a></div>
            <div class="time">#{Calendar.strftime(waypoint.time, "%Y-%m-%d %H:%M UTC")}</div>
          ]]>
        </desc>
        <ele>#{waypoint.ele}</ele>
        <time>#{DateTime.to_iso8601(waypoint.time)}</time>
      </wpt>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_tracks(tracks) do
    Enum.map(tracks, fn track ->
      """
      <trk>
        <name>#{track.name}</name>
        #{render_segments(track.segments)}
      </trk>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_segments(segments) do
    Enum.map(segments, fn segment ->
      """
      <trkseg>
        #{render_trackpoints(segment.trackpoints)}
      </trkseg>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_trackpoints(trackpoints) do
    Enum.map(trackpoints, fn trackpoint ->
      """
      <trkpt lat="#{trackpoint.lat}" lon="#{trackpoint.lon}">
        <ele>#{trackpoint.ele}</ele>
        <time>#{DateTime.to_iso8601(trackpoint.time)}</time>
      </trkpt>
      """
    end)
    |> Enum.join("\n")
  end
end
