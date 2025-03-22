import Ecto.Query
alias Klaxon.Repo
alias Klaxon.Traces.Trace
alias Klaxon.Traces.Track
alias Klaxon.Traces.Segment
alias Klaxon.Traces.Trackpoint
alias Klaxon.Traces.Waypoint

defmodule ReconstituteTraceJson do
  def fetch_trace() do
    trace = Repo.one((from t in Trace, preload: [:waypoints, tracks: [segments: :trackpoints]]) |> first())
    {:ok, trace_json} = Jason.encode(trace)
    {:ok, trace_map} = Jason.decode(trace_json, keys: :atoms)
    trace_map
  end

  def reconsitute_trace(trace) do
    trace = struct(Trace, trace)
    |> Map.put(:tracks, Enum.map(trace.tracks, &reconsitute_track/1))
    |> Map.put(:waypoints, Enum.map(trace.waypoints, &reconsitute_waypoint/1))
  end

  defp reconsitute_track(track) do
    track = struct(Track, track)
    |> Map.put(:segments, Enum.map(track.segments, &reconsitute_segment/1))
  end

  defp reconsitute_segment(segment) do
    segment = struct(Segment, segment)
    |> Map.put(:trackpoints, Enum.map(segment.trackpoints, &reconsitute_trackpoint/1))
  end

  defp reconsitute_trackpoint(trackpoint) do
    struct(Trackpoint, trackpoint)
  end

  defp reconsitute_waypoint(waypoint) do
    struct(Waypoint, waypoint)
  end
end

trace_recon =
  ReconstituteTraceJson.fetch_trace()
  |> ReconstituteTraceJson.reconsitute_trace()

trace_recon
