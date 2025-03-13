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

  def get_traces do
    subquery =
      from(w in Waypoint,
        group_by: w.trace_id,
        select: %{trace_id: w.trace_id, min_created_at: min(w.created_at)}
      )

    query =
      from(t in Trace,
        join: w in subquery(subquery),
        on: t.id == w.trace_id,
        preload: :waypoints,
        order_by: w.min_created_at,
        select_merge: %{created_at: w.min_created_at}
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
  def get_trace(id) do
    case from(t in Trace,
           where: t.id == ^id,
           preload: [:waypoints, tracks: [segments: :trackpoints]]
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
      {:ok, created_at, 0} = DateTime.from_iso8601(waypoint.time)

      insert_waypoint(%{
        trace_id: trace_id,
        name: waypoint.name,
        lat: waypoint.lat,
        lon: waypoint.lon,
        ele: waypoint.ele,
        created_at: created_at
      })
    end
  end

  defp import_tracks(tracks, trace_id) do
    for track <- tracks do
      {:ok, inserted_track} = insert_track(%{trace_id: trace_id, name: track.name})

      for segment <- track.segments do
        {:ok, inserted_segment} = insert_segment(%{track_id: inserted_track.id})

        for trackpoint <- segment.trackpoints do
          {:ok, created_at, 0} = DateTime.from_iso8601(trackpoint.time)

          insert_trackpoint(%{
            segment_id: inserted_segment.id,
            lat: trackpoint.lat,
            lon: trackpoint.lon,
            ele: trackpoint.ele,
            created_at: created_at
          })
        end
      end
    end
  end

  def insert_trace(attrs) do
    %Trace{}
    |> Trace.changeset(attrs)
    |> Repo.insert()
  end

  def insert_track(attrs) do
    %Track{}
    |> Track.changeset(attrs)
    |> Repo.insert()
  end

  def insert_segment(attrs) do
    %Segment{}
    |> Segment.changeset(attrs)
    |> Repo.insert()
  end

  def insert_trackpoint(attrs) do
    %Trackpoint{}
    |> Trackpoint.changeset(attrs)
    |> Repo.insert()
  end

  def insert_waypoint(attrs) do
    %Waypoint{}
    |> Waypoint.changeset(attrs)
    |> Repo.insert()
  end

  def delete_trace(trace) do
    Repo.delete(trace)
  end

  def render_trace_as_gpx(trace_id) do
    case get_trace(trace_id) do
      {:ok, trace} ->
        gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Klaxon">
          <metadata>
            <name>#{trace.name}</name>
          </metadata>
          #{render_waypoints(trace.waypoints)}
          #{render_tracks(trace.tracks)}
        </gpx>
        """

        {:ok, gpx}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp render_waypoints(waypoints) do
    Enum.map(waypoints, fn waypoint ->
      """
      <wpt lat="#{waypoint.lat}" lon="#{waypoint.lon}">
        <name>#{waypoint.name}</name>
        <ele>#{waypoint.ele}</ele>
        <time>#{DateTime.to_iso8601(waypoint.created_at)}</time>
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
        <time>#{DateTime.to_iso8601(trackpoint.created_at)}</time>
      </trkpt>
      """
    end)
    |> Enum.join("\n")
  end
end
