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

  def import_trace(path, attrs) do
    doc = parse(File.stream!(path))

    # trace
    {:ok, trace} = insert_trace(attrs)

    # waypoints
    for waypoint_element <- xpath(doc, ~x"//wpt"el) do
      name = xpath(waypoint_element, ~x"//name/text()"s)
      lat = String.to_float(xpath(waypoint_element, ~x"@lat"s))
      lon = String.to_float(xpath(waypoint_element, ~x"@lon"s))
      ele = String.to_float(xpath(waypoint_element, ~x"//ele/text()"s))
      {:ok, time, 0} = DateTime.from_iso8601(xpath(waypoint_element, ~x"//time/text()"s))

      insert_waypoint(%{
        trace_id: trace.id,
        name: name,
        lat: lat,
        lon: lon,
        ele: ele,
        created_at: time
      })
    end

    # tracks
    for track_element <- xpath(doc, ~x"//trk"el) do
      name = xpath(track_element, ~x"//name/text()"s)
      {:ok, track} = insert_track(%{trace_id: trace.id, name: name})

      # segments
      for segment_element <- xpath(track_element, ~x"//trkseg"el) do
        {:ok, segment} = insert_segment(%{track_id: track.id})

        # trackpoints
        for trackpoint_element <- xpath(segment_element, ~x"//trkpt"el) do
          name = xpath(trackpoint_element, ~x"//name/text()"s)
          lat = String.to_float(xpath(trackpoint_element, ~x"@lat"s))
          lon = String.to_float(xpath(trackpoint_element, ~x"@lon"s))
          ele = String.to_float(xpath(trackpoint_element, ~x"//ele/text()"s))
          {:ok, time, 0} = DateTime.from_iso8601(xpath(trackpoint_element, ~x"//time/text()"s))

          insert_trackpoint(%{
            segment_id: segment.id,
            name: name,
            lat: lat,
            lon: lon,
            ele: ele,
            created_at: time
          })
        end
      end
    end

    get_trace(trace.id)
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
