import Ecto.Query
alias Klaxon.Repo
alias Klaxon.Traces.Processor
alias Klaxon.Traces.Trace
alias Klaxon.Traces.Track
alias Klaxon.Traces.Segment
alias Klaxon.Traces.Trackpoint
alias Klaxon.Traces.Waypoint

defmodule ReprocessTrace do
  def reprocess_trace_by_id(trace_id) do
    trace =
      Repo.get(Trace, trace_id)
      |> Repo.preload([:waypoints, tracks: [segments: :trackpoints]])
      |> Processor.preprocess_trace()
  end
end
