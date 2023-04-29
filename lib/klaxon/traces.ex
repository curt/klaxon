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

  def get_trace(id) do
    case from(t in Trace,
           left_join: x in assoc(t, :tracks),
           left_join: w in assoc(t, :waypoints),
           left_join: s in assoc(x, :segments),
           left_join: p in assoc(s, :trackpoints),
           where: t.id == ^id,
           preload: [tracks: {x, segments: {s, trackpoints: p}}, waypoints: w]
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
end
