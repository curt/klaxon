import Ecto.Changeset
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

    processed_trace =
      trace
      |> Repo.preload([:waypoints, tracks: [segments: :trackpoints]])
      |> Processor.preprocess_trace()
      |> Processor.process_trace()
      |> Map.put(:profile_id, trace.profile_id)
      |> Map.put(:visibility, :public)
      |> Map.put(:status, :processed)
      |> Repo.insert!()

    trace
    |> change(%{visibility: :unlisted})
    |> Repo.update!()
  end
end
