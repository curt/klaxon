defmodule Klaxon.Traces.Processor do
  @moduledoc """
  Processes GPX trace to remove redundant data points and detect stops.
  """

  alias Klaxon.Traces.Trace
  alias Klaxon.Traces.Track
  alias Klaxon.Traces.Segment
  alias Klaxon.Traces.Trackpoint
  alias Klaxon.Traces.Waypoint

  @type go_or_stop() :: :go | :stop
  @type trackpoint() :: %Trackpoint{lon: float(), lat: float(), created_at: DateTime.t()}
  @type trackpoints() :: [Trackpoint.t()]
  @type trackpoint_group() :: {go_or_stop(), trackpoints()}
  @type trackpoint_groups() :: [trackpoint_group()]
  @type waypoints() :: [Waypoint.t()]

  # meters
  @default_radius 50.0
  # seconds (5 minutes)
  @default_duration 300.0
  # meters/second
  @default_speed 1.4
  # seconds
  @default_time_gap 5
  # meters
  @default_distance_gap 5

  @doc """
  Preprocess a trace by removing redundant trackpoints.
  ## Parameters
  - trace: The trace to preprocess.
  - opts: A keyword list of options.
  ## Options
  - :time_gap: The minimum time gap between trackpoints (in seconds).
  - :distance_gap: The minimum distance between trackpoints (in meters).
  ## Examples
      iex> trace = %Trace{tracks: [%Track{segments: [%Segment{trackpoints: trackpoints}]}}}
      iex> preprocess_trace(trace)
      %Trace{tracks: [%Track{segments: [%Segment{trackpoints: trackpoints}]}}}
  """
  def preprocess_trace(%Trace{tracks: tracks} = trace, opts \\ []) do
    time_gap = Keyword.get(opts, :time_gap, @default_time_gap)
    distance_gap = Keyword.get(opts, :distance_gap, @default_distance_gap)

    %{trace | tracks: Enum.map(tracks, &preprocess_track(&1, time_gap, distance_gap))}
  end

  def preprocess_track(%Track{segments: segments} = track, time_gap, distance_gap) do
    %{track | segments: Enum.map(segments, &preprocess_segment(&1, time_gap, distance_gap))}
  end

  def preprocess_segment(%Segment{trackpoints: trackpoints}, time_gap, distance_gap) do
    filtered_trackpoints = filter_trackpoints(trackpoints, time_gap, distance_gap)
    %Segment{trackpoints: filtered_trackpoints}
  end

  @doc """
  Filter trackpoints based on time and distance gaps.
  Removes any trackpoints that are too close together in time or distance.
  The first and last trackpoints are always kept.
  ## Parameters
  - trackpoints: The list of trackpoints to filter.
  - time_gap: The minimum time gap between trackpoints (in seconds).
  - distance_gap: The minimum distance between trackpoints (in meters).
  ## Examples
      iex> trackpoints = [
      ...>   %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
      ...>   %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 2)}
      ...> ]
      iex> filter_trackpoints(trackpoints, 5, 10)
      [
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 2)}
      ]
  """
  def filter_trackpoints([], _time_gap, _distance_gap), do: []

  def filter_trackpoints(rest, _time_gap, _distance_gap) when is_list(rest) and length(rest) == 1,
    do: [rest]

  def filter_trackpoints([first | rest], time_gap, distance_gap) do
    # Split the list into all but the last element and the last element.
    {rest, last} = rest |> Enum.split(-1)

    # The accumulator is a tuple containing the list of trackpoints to keep and the last trackpoint kept.
    Enum.reduce(rest, {[first], first}, fn point, {acc, last_kept} ->
      # The last trackpoint is kept if it meets the time and distance requirements.
      if should_keep_trackpoint?(last_kept, point, time_gap, distance_gap) do
        {[last_kept | acc], point}
      else
        {acc, last_kept}
      end
    end)
    # The list of trackpoints to keep is extracted from the accumulator.
    |> elem(0)
    # The list of trackpoints to keep is reversed and concatenated with the last trackpoint.
    |> Enum.reverse()
    |> Enum.concat([last])
  end

  # Determine if a trackpoint should be kept based on time and distance gaps.
  # Uses Haversine formula to calculate distance between two points.
  defp should_keep_trackpoint?(point1, point2, time_gap, distance_gap) do
    # Calculate the distance between the two points in meters.
    distance = distance(point1, point2)
    # Calculate the time difference in seconds.
    time_diff = abs(DateTime.diff(point1.created_at, point2.created_at, :second))

    distance >= distance_gap or time_diff >= time_gap
  end

  @doc """
  Process a list of trackpoints to generate trackpoints and waypoints.
  ## Parameters
  - trackpoints: The list of trackpoints to process.
  - opts: A keyword list of options.
  ## Options
  - :radius: The radius (in meters) to use for detecting stops.
  - :duration: The minimum duration (in seconds) for a stop group.
  - :speed: The speed (in meters/second) to use for estimating trackpoints.
  ## Examples
      iex> trackpoints = [
      ...>   %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
      ...>   %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 2)}
      ...> ]
      iex> process_trackpoints(trackpoints)
      {trackpoints, waypoints}
  """
  @spec process_trackpoints([Klaxon.Traces.Trackpoint.t()]) :: {trackpoints(), waypoints()}
  @spec process_trackpoints([Klaxon.Traces.Trackpoint.t()], keyword()) ::
          {trackpoints(), waypoints()}
  def process_trackpoints(trackpoints, opts \\ []) do
    radius = Keyword.get(opts, :radius, @default_radius)
    duration = Keyword.get(opts, :duration, @default_duration)
    speed = Keyword.get(opts, :speed, @default_speed)

    trackpoint_groups =
      trackpoints
      |> chunk_trackpoints_by_radius(radius)
      |> remap_trackpoint_groups_by_duration(duration)
      |> recombine_trackpoint_groups_by_type()
      |> apply_centerpoint_to_stop_groups()

    waypoints = trackpoint_groups |> generate_waypoints_from_trackpoint_groups()

    trackpoint_groups =
      trackpoint_groups
      |> apply_assumed_trackpoints(1, speed)
      |> Enum.reverse()
      |> apply_assumed_trackpoints(-1, speed)
      |> Enum.reverse()

    trackpoints =
      trackpoint_groups
      |> filter_go_groups()
      |> Enum.map(&emit_trackpoints/1)
      |> List.flatten()
      |> Enum.sort(&(DateTime.to_unix(&1.created_at) < DateTime.to_unix(&2.created_at)))

    {trackpoints, waypoints}
  end

  @spec generate_waypoints_from_trackpoint_groups(trackpoints()) :: waypoints()
  def generate_waypoints_from_trackpoint_groups(trackpoint_groups) do
    trackpoint_groups
    |> filter_stop_groups()
    |> Enum.map(fn
      {:stop, trkpts, {lon, lat} = _ctrpt} ->
        %Waypoint{
          name: "Stop",
          lon: lon,
          lat: lat,
          created_at: datetime_of_trackpoints(trkpts)
        }
    end)
  end

  @doc """
  Chunks a list of trackpoints into groups of goes and stops.
  ## Parameters
  - trackpoints: The list of trackpoints to process.
  - opts: A keyword list of options.
  ## Options
  - :radius: The radius (in meters) to use for detecting stops.
  """
  @spec chunk_trackpoints_by_radius(trackpoints()) :: trackpoint_groups()
  @spec chunk_trackpoints_by_radius(trackpoints(), float()) :: trackpoint_groups()
  def chunk_trackpoints_by_radius(trackpoints, radius \\ @default_radius)
  def chunk_trackpoints_by_radius([], _radius), do: []

  def chunk_trackpoints_by_radius(trackpoints, radius)
      when is_float(radius) do
    trackpoints
    |> Enum.chunk_while(
      [],
      fn
        # Start a new go group if there’s no accumulator.
        p, [] ->
          {:cont, {:go, [p]}}

        # For a go group, pattern-match the accumulator into the most recent point and the rest.
        p, {:go, [last | rest] = acc} ->
          d = distance(p, last)

          if d < radius do
            # Emit the go group without its last trackpoint (i.e. [last]) and
            # start a stop group with the removed point and the current point.
            {:cont, {:go, Enum.reverse(rest)}, {:stop, [last, p]}}
          else
            # Continue adding to the current go group.
            {:cont, {:go, [p | acc]}}
          end

        # For a stop group, keep adding points if the distance condition holds.
        p, {:stop, trkpts} ->
          d = distance(p, hd(trkpts))

          if d < radius do
            {:cont, {:stop, [p | trkpts]}}
          else
            {:cont, {:stop, Enum.reverse(trkpts)}, {:go, [p]}}
          end
      end,
      # When finished, simply emit the last accumulated group.
      fn {group_type, trkpts} ->
        {:cont, {group_type, trkpts}, nil}
      end
    )
  end

  @doc """
  Remap trackpoint groups by duration.
  ## Parameters
  - trackpoint_groups: The list of trackpoint groups to process.
  - duration: The minimum duration (in seconds) for a stop group.
  """
  @spec remap_trackpoint_groups_by_duration(trackpoint_groups()) :: trackpoint_groups()
  @spec remap_trackpoint_groups_by_duration(trackpoint_groups(), float()) :: trackpoint_groups()
  def remap_trackpoint_groups_by_duration(trackpoint_groups, duration \\ @default_duration)
  def remap_trackpoint_groups_by_duration([], _duration), do: []

  def remap_trackpoint_groups_by_duration(trackpoint_groups, duration) do
    trackpoint_groups
    |> Enum.map(fn
      # Handle a go group by re-emitting.
      {:go, _trkpts} = elem ->
        elem

      # Handle a stop group.
      {:stop, trkpts} = elem ->
        if length(trkpts) == 1 do
          # If the stop group only has one trackpoint, re-emit it as a go group.
          {:go, trkpts}
        else
          start_time = hd(trkpts).created_at
          end_time = List.last(trkpts).created_at
          time_diff = abs(DateTime.diff(start_time, end_time, :second))

          if time_diff < duration do
            # If the stop group is less than the duration, re-emit it as a go group.
            {:go, trkpts}
          else
            # If the stop group is greater than or equal to the duration, re-emit.
            elem
          end
        end
    end)
  end

  @doc """
  Recombine trackpoint groups by type.
  ## Parameters
  - trackpoint_groups: The list of trackpoint groups to process.
  ## Examples
      iex> trackpoint_groups = [
      ...>   {:go, [trackpoint1, trackpoint2]},
      ...>   {:go, [trackpoint3, trackpoint4]},
      ...>   {:stop, [trackpoint5, trackpoint6]}
      ...> ]
      iex> recombine_trackpoint_groups_by_type(trackpoint_groups)
      [
        {:go, [trackpoint1, trackpoint2, trackpoint3, trackpoint4]},
        {:stop, [trackpoint5, trackpoint6]}
      ]
  """
  @spec recombine_trackpoint_groups_by_type(trackpoint_groups()) :: trackpoint_groups()
  def recombine_trackpoint_groups_by_type([]), do: []

  def recombine_trackpoint_groups_by_type(trackpoint_groups) do
    trackpoint_groups
    |> Enum.chunk_while(
      [],
      fn
        # Handle first group
        elem, [] ->
          {:cont, elem}

        # Handle subsequent groups
        {go_or_stop, trkpts}, {go_or_stop_acc, trkpts_acc} ->
          if go_or_stop == go_or_stop_acc do
            # If the group type is the same, add the trackpoints to the accumulator.
            {:cont, {go_or_stop_acc, trkpts_acc ++ trkpts}}
          else
            # If the group type is different, emit the accumulator and start a new group.
            {:cont, {go_or_stop_acc, trkpts_acc}, {go_or_stop, trkpts}}
          end
      end,
      fn
        # Emit the last group.
        {go_or_stop_acc, trkpts_acc} ->
          {:cont, {go_or_stop_acc, trkpts_acc}, nil}
      end
    )
  end

  @doc """
  Apply the centerpoint to stop groups.
  ## Parameters
  - trackpoint_groups: The list of trackpoint groups to process.
  ## Examples
      iex> trackpoint_groups = [
      ...>   {:go, [trackpoint1, trackpoint2]},
      ...>   {:stop, [trackpoint3, trackpoint4]}
      ...> ]
      iex> apply_centerpoint_to_stop_groups(trackpoint_groups)
      [
        {:go, [trackpoint1, trackpoint2]},
        {:stop, [trackpoint3, trackpoint4], centerpoint}
      ]
  """
  @spec apply_centerpoint_to_stop_groups(trackpoint_groups()) :: trackpoint_groups()
  def apply_centerpoint_to_stop_groups(trackpoint_groups) do
    trackpoint_groups
    |> Enum.map(fn
      {:go, trkpts} -> {:go, trkpts}
      {:stop, trkpts} -> {:stop, trkpts, center_of_trackpoints(trkpts, :spherical)}
    end)
  end

  @doc """
  Apply assumed trackpoints for travel from last trackpoint in go group
  to centerpoint in next stop group.
  ## Parameters
  - trackpoint_groups: The list of trackpoint groups to process.
  - factor: The factor to apply to the travel time (an integer, usually 1 or -1).
  ## Examples
      iex> trackpoint_groups = [
      ...>   {:go, [trackpoint1, trackpoint2]},
      ...>   {:stop, [trackpoint3, trackpoint4], centerpoint},
      ...>   {:go, [trackpoint5, trackpoint6]}
      ...> ]
      iex> apply_assumed_trackpoints(trackpoint_groups, 1)
      [
        {:go, [trackpoint1, trackpoint2, new_trackpoint]},
        {:stop, [trackpoint3, trackpoint4], centerpoint},
        {:go, [trackpoint5, trackpoint6, trackpoint7]}
      ]
  """
  @spec apply_assumed_trackpoints(trackpoint_groups(), integer()) :: trackpoint_groups()
  @spec apply_assumed_trackpoints(trackpoint_groups(), integer(), float()) :: trackpoint_groups()
  def apply_assumed_trackpoints(trackpoint_groups, factor, speed \\ @default_speed) do
    trackpoint_groups
    |> Enum.chunk_every(2, 1)
    |> Enum.map(fn
      [{:go, go_trkpts}, {:stop, _stop_trkpts, {lon, lat} = _ctrpt}] ->
        # Assume travel from last trackpoint in go group to centerpoint in stop group
        {:go,
         go_trkpts ++
           [
             %Trackpoint{
               lon: lon,
               lat: lat,
               created_at:
                 estimate_time_based_on_speed(
                   List.last(go_trkpts),
                   %{lon: lon, lat: lat},
                   factor,
                   speed
                 )
             }
           ]}

      [{:stop, _stop_trkpts, _ctrpt} = p, _] ->
        p

      [p] ->
        p
    end)
    |> List.flatten()
  end

  @doc """
  Reject stop groups from a list of trackpoint groups.
  ## Parameters
  - trackpoint_groups: The list of trackpoint groups to process.
  ## Examples
      iex> trackpoint_groups = [
      ...>   {:go, [trackpoint1, trackpoint2]},
      ...>   {:stop, [trackpoint3, trackpoint4], centerpoint},
      ...>   {:go, [trackpoint5, trackpoint6]}
      ...> ]
      iex> reject_stop_groups(trackpoint_groups)
      [
        {:go, [trackpoint1, trackpoint2]},
        {:go, [trackpoint5, trackpoint6]}
      ]
  """
  def filter_go_groups(trackpoint_groups) do
    trackpoint_groups
    |> Enum.filter(&is_go_group/1)
  end

  defp is_go_group({:go, _trkpts}), do: true
  defp is_go_group(_), do: false

  def filter_stop_groups(trackpoint_groups) do
    trackpoint_groups
    |> Enum.filter(&is_stop_group/1)
  end

  defp is_stop_group({:stop, _trkpts}), do: true
  defp is_stop_group({:stop, _trkpts, _ctrpt}), do: true
  defp is_stop_group(_), do: false

  defp emit_trackpoints({:go, trkpts}), do: trkpts

  # Compute center of a list of trackpoints.
  @doc """
  Compute the center of a list of trackpoints.
  ## Parameters
  - trackpoints: The list of trackpoints to process.
  - coord_type: The type of coordinates to use for the centerpoint.
  ## Examples
      iex> trackpoints = [
      ...>   %Trackpoint{lat: 40.1, lon: -105.1},
      ...>   %Trackpoint{lat: 40.2, lon: -105.2},
      ...>   %Trackpoint{lat: 40.3, lon: -105.3}
      ...> ]
      iex> center_of_trackpoints(trackpoints, :cartesian)
      {40.2, -105.2}
  """
  @spec center_of_trackpoints(trackpoints(), :cartesian | :spherical) :: {float(), float()}
  def center_of_trackpoints(trackpoints, :cartesian) do
    {lon, lat} =
      trackpoints
      |> Enum.map(&coordinates/1)
      |> Enum.reduce({0.0, 0.0}, fn {lon1, lat1}, {lon2, lat2} -> {lon1 + lon2, lat1 + lat2} end)

    {lon / length(trackpoints), lat / length(trackpoints)}
  end

  def center_of_trackpoints(trackpoints, :spherical) do
    {sum_x, sum_y, sum_z, count} =
      trackpoints
      |> Enum.map(&coordinates/1)
      |> Enum.reduce({0.0, 0.0, 0.0, 0}, fn {lon, lat}, {sx, sy, sz, cnt} ->
        # Convert from degrees to radians
        lon_rad = deg2rad(lon)
        lat_rad = deg2rad(lat)
        # Convert lat/lon to 3D Cartesian coordinates on a unit sphere
        x = :math.cos(lat_rad) * :math.cos(lon_rad)
        y = :math.cos(lat_rad) * :math.sin(lon_rad)
        z = :math.sin(lat_rad)
        {sx + x, sy + y, sz + z, cnt + 1}
      end)

    # Compute average Cartesian coordinates
    avg_x = sum_x / count
    avg_y = sum_y / count
    avg_z = sum_z / count

    # Convert average Cartesian coordinates back to lat/lon
    lon_center = rad2deg(:math.atan2(avg_y, avg_x))
    hyp = :math.sqrt(avg_x * avg_x + avg_y * avg_y)
    lat_center = rad2deg(:math.atan2(avg_z, hyp))

    {lon_center, lat_center}
  end

  defp deg2rad(deg), do: deg * :math.pi() / 180.0
  defp rad2deg(rad), do: rad * 180.0 / :math.pi()

  def datetime_of_trackpoints([%{created_at: first} | _] = trackpoints) do
    last = List.last(trackpoints).created_at
    seconds_diff = DateTime.diff(last, first, :second)
    DateTime.add(first, div(seconds_diff, 2), :second)
  end

  @doc """
  Estimate the time of a trackpoint based on an assumed speed between two points.
  ## Parameters
  - trkpt1: The first trackpoint.
  - trkpt2: The second trackpoint.
  - factor: The factor to apply to the travel time (an integer, usually 1 or -1).
  - speed: The speed to use for the travel time calculation.
  ## Examples
      iex> trkpt1 = %Trackpoint{created_at: DateTime.utc_now(), lat: 40.1, lon: -105.1}
      iex> trkpt2 = %Trackpoint{lat: 40.2, lon: -105.2}
      iex> estimate_time_based_on_speed(trkpt1, trkpt2, 1, 1.4)
      %DateTime{...}
  """
  @spec estimate_time_based_on_speed(trackpoint(), %{lon: float(), lat: float()}, integer()) ::
          DateTime.t()
  @spec estimate_time_based_on_speed(
          trackpoint(),
          %{lon: float(), lat: float()},
          integer(),
          float()
        ) ::
          DateTime.t()
  def estimate_time_based_on_speed(
        %{created_at: time, lat: _, lon: _} = trkpt1,
        %{lat: _, lon: _} = trkpt2,
        factor,
        speed \\ @default_speed
      ) do
    dist = distance(trkpt1, trkpt2)
    time_shift = round(dist / speed) * factor
    DateTime.add(time, time_shift, :second)
  end

  # Calculate the distance (in meters) between two trackpoints or waypoints.
  defp distance(point1, point2),
    do: Haversine.distance(coordinates(point1), coordinates(point2))

  # Get coordinates from a trackpoint or waypoint.
  defp coordinates(%{lon: lon, lat: lat}), do: {lon, lat}
end
