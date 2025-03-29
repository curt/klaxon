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
  @type trace() :: %Trace{tracks: [Track.t()], waypoints: [Waypoint.t()]}
  @type trackpoint() :: %Trackpoint{lon: float(), lat: float(), time: DateTime.t()}
  @type trackpoints() :: Enumerable.t(Trackpoint.t())
  @type trackpoint_group() :: {go_or_stop(), trackpoints()}
  @type trackpoint_groups() :: Enumerable.t(trackpoint_group())
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
  @spec preprocess_trace(trace()) :: trace()
  @spec preprocess_trace(trace(), keyword()) :: trace()
  def preprocess_trace(%Trace{} = trace, opts \\ []) do
    time_gap = Keyword.get(opts, :time_gap, @default_time_gap)
    distance_gap = Keyword.get(opts, :distance_gap, @default_distance_gap)

    %Trace{
      name: trace.name,
      tracks: Enum.map(trace.tracks, &preprocess_track(&1, time_gap, distance_gap)),
      waypoints: Enum.map(trace.waypoints, &preprocess_waypoint/1)
    }
  end

  defp preprocess_track(%Track{} = track, time_gap, distance_gap) do
    %Track{
      name: track.name,
      segments: Enum.map(track.segments, &preprocess_segment(&1, time_gap, distance_gap))
    }
  end

  defp preprocess_segment(%Segment{} = segment, time_gap, distance_gap) do
    trackpoints = filter_trackpoints(segment.trackpoints, time_gap, distance_gap)
    %Segment{trackpoints: Enum.map(trackpoints, &preprocess_trackpoint/1)}
  end

  defp preprocess_trackpoint(%Trackpoint{} = trackpoint) do
    %Trackpoint{
      lat: trackpoint.lat,
      lon: trackpoint.lon,
      ele: trackpoint.ele,
      time: trackpoint.time
    }
  end

  defp preprocess_waypoint(%Waypoint{} = waypoint) do
    %Waypoint{
      name: waypoint.name,
      lon: waypoint.lon,
      lat: waypoint.lat,
      ele: waypoint.ele,
      time: waypoint.time
    }
  end

  @doc """
    Filter trackpoints based on time and distance gaps.
    ## Parameters
    - trackpoints: The list of trackpoints to filter.
    - time_gap: The minimum time gap between trackpoints (in seconds).
    - distance_gap: The minimum distance between trackpoints (in meters).
  """
  def filter_trackpoints([], _time_gap, _distance_gap), do: []

  def filter_trackpoints(rest, _time_gap, _distance_gap) when is_list(rest) and length(rest) == 1,
    do: rest

  def filter_trackpoints(trackpoints, time_gap, distance_gap) do
    # Filter the trackpoints based on time and distance gaps.
    trackpoints
    # Chunk the trackpoints into pairs.
    |> Stream.chunk_every(2, 1)
    # Transform the stream to process each pair of trackpoints.
    |> Stream.transform(nil, fn
      [point1, point2], last_emitted ->
        if last_emitted == nil do
          # If there is no last emitted trackpoint, emit the first trackpoint.
          if should_keep_trackpoint?(point1, point2, time_gap, distance_gap) do
            # Emit the second trackpoint if it meets the criteria.
            {[point1, point2], point2}
          else
            {[point1], point1}
          end
        else
          # If there is a last emitted trackpoint, do not emit the first trackpoint.
          if should_keep_trackpoint?(last_emitted, point2, time_gap, distance_gap) do
            # Emit the second trackpoint if it meets the criteria.
            {[point2], point2}
          else
            {[], last_emitted}
          end
        end

      # Emit the last trackpoint unless it was already emitted.
      [point1], last_emitted ->
        if same_trackpoint?(point1, last_emitted) do
          {[], last_emitted}
        else
          {[point1], point1}
        end
    end)
  end

  # Determine if a trackpoint should be kept based on time and distance gaps.
  # Uses Haversine formula to calculate distance between two points.
  defp should_keep_trackpoint?(point1, point2, time_gap, distance_gap) do
    # Calculate the distance between the two points in meters.
    distance = distance(point1, point2)
    # Calculate the time difference in seconds.
    time_diff = abs(DateTime.diff(point1.time, point2.time, :second))

    distance >= distance_gap or time_diff >= time_gap
  end

  # Determine whether two trackpoints are the same based on their time.
  defp same_trackpoint?(point1, point2) do
    point1.time == point2.time and point1.time == point2.time
  end

  def process_trace(trace, opts \\ []) do
    {tracks, waypoints} = process_tracks(trace.tracks, opts)
    Map.merge(trace, %{tracks: tracks, waypoints: trace.waypoints ++ waypoints})
  end

  def process_tracks(tracks, opts \\ []) do
    Enum.reduce(tracks, {[], []}, fn track, {acc_tracks, acc_waypoints} ->
      {segments, waypoints} =
        Enum.reduce(
          track.segments,
          {[], []},
          fn segment, {acc_segments, acc_waypoints} ->
            {trackpoints_lists, waypoints} = process_trackpoints(segment.trackpoints, opts)

            segments =
              Enum.map(trackpoints_lists, fn trackpoints -> %Segment{trackpoints: trackpoints} end)

            {acc_segments ++ segments, acc_waypoints ++ waypoints}
          end
        )

      {acc_tracks ++ [%Track{segments: segments}], acc_waypoints ++ waypoints}
    end)
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
      ...>   %Trackpoint{lat: 40.1, lon: -105.1, time: DateTime.utc_now()},
      ...>   %Trackpoint{lat: 40.1, lon: -105.1, time: DateTime.add(DateTime.utc_now(), 2)}
      ...> ]
      iex> process_trackpoints(trackpoints)
      {trackpoints, waypoints}
  """
  @spec process_trackpoints([Klaxon.Traces.Trackpoint.t()]) :: {list(trackpoints()), waypoints()}
  @spec process_trackpoints([Klaxon.Traces.Trackpoint.t()], keyword()) ::
          {list(trackpoints()), waypoints()}
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

    trackpoints_lists =
      trackpoint_groups
      |> filter_go_groups()
      |> Enum.map(&emit_sorted_trackpoints/1)

    {trackpoints_lists, waypoints}
  end

  @spec generate_waypoints_from_trackpoint_groups(trackpoint_groups()) :: waypoints()
  def generate_waypoints_from_trackpoint_groups(trackpoint_groups) do
    trackpoint_groups
    |> filter_stop_groups()
    |> Enum.map(fn
      {:stop, trkpts, {lon, lat} = _ctrpt} ->
        %Waypoint{
          name: "Stop",
          lon: lon,
          lat: lat,
          ele: elevation_of_trackpoints(trkpts),
          time: datetime_of_trackpoints(trkpts)
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

  def chunk_trackpoints_by_radius(trackpoints, radius) when is_float(radius) do
    trackpoints
    |> Stream.chunk_while(
      [],
      &chunk_step(&1, &2, radius),
      &chunk_after/1
    )
  end

  # Handles each incoming trackpoint based on the current accumulator.
  defp chunk_step(p, [] = _acc, _radius) do
    # Start a new "go" group if there is no accumulator.
    {:cont, {:go, [p], p}}
  end

  defp chunk_step(p, {:go, trkpts, last} = _acc, radius) do
    chunk_handle_go_group(p, trkpts, last, radius)
  end

  defp chunk_step(p, {:stop, trkpts, first} = _acc, radius) do
    chunk_handle_stop_group(p, trkpts, first, radius)
  end

  # Emits the final group when the input is exhausted.
  defp chunk_after({group_type, trkpts, _}) do
    {:cont, {group_type, Enum.reverse(trkpts)}, nil}
  end

  # Helper function for handling a "go" group.
  defp chunk_handle_go_group(p, [last | rest] = trkpts, last, radius) do
    d = distance(p, last)

    if d < radius do
      # When the distance exceeds the radius, remove the last trackpoint from the go group,
      # emit the group (without that last trackpoint) and start a new "stop" group with both the removed point and the current point.
      {:cont, {:go, Enum.reverse(rest)}, {:stop, [last, p], p}}
    else
      # Otherwise, continue adding the point to the go group.
      {:cont, {:go, [p | trkpts], p}}
    end
  end

  # Helper function for handling a "stop" group.
  defp chunk_handle_stop_group(p, trkpts, first, radius) do
    d = distance(p, first)

    if d < radius do
      # Continue the stop group.
      {:cont, {:stop, [p | trkpts], first}}
    else
      # End the current stop group and start a new go group.
      {:cont, {:stop, Enum.reverse(trkpts)}, {:go, [p], p}}
    end
  end

  @doc """
  Remap trackpoint groups by duration.
  ## Parameters
  - trackpoint_groups: The list of trackpoint groups to process.
  - duration: The minimum duration (in seconds) for a stop group.
  ## Examples
      iex> trackpoint_groups = [
      ...>   {:go, [trackpoint1, trackpoint2]},
      ...>   {:stop, [trackpoint3, trackpoint4]} # Where duration is less than specified
      ...> ]
      iex> remap_trackpoint_groups_by_duration(trackpoint_groups) |> Enum.to_list()
      [
        {:go, [trackpoint1, trackpoint2]},
        {:go, [trackpoint3, trackpoint4]}
      ]
  """
  @spec remap_trackpoint_groups_by_duration(trackpoint_groups()) :: trackpoint_groups()
  @spec remap_trackpoint_groups_by_duration(trackpoint_groups(), float()) :: trackpoint_groups()
  def remap_trackpoint_groups_by_duration(trackpoint_groups, duration \\ @default_duration)
  def remap_trackpoint_groups_by_duration([], _duration), do: []

  def remap_trackpoint_groups_by_duration(trackpoint_groups, duration) do
    trackpoint_groups
    |> Stream.map(&remap_step(&1, duration))
  end

  # Handles each incoming trackpoint group.
  defp remap_step({:go, trkpts}, _duration), do: {:go, trkpts}

  defp remap_step({:stop, trkpts} = elem, duration) do
    if length(trkpts) == 1 do
      # If the stop group only has one trackpoint, re-emit it as a go group.
      {:go, trkpts}
    else
      start_time = hd(trkpts).time
      end_time = List.last(trkpts).time
      time_diff = abs(DateTime.diff(start_time, end_time, :second))

      if time_diff < duration do
        # If the stop group is less than the duration, re-emit as a go group.
        {:go, trkpts}
      else
        # If the stop group is greater than or equal to the duration, re-emit.
        elem
      end
    end
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
      iex> recombine_trackpoint_groups_by_type(trackpoint_groups) |> Enum.to_list()
      [
        {:go, [trackpoint1, trackpoint2, trackpoint3, trackpoint4]},
        {:stop, [trackpoint5, trackpoint6]}
      ]
  """
  @spec recombine_trackpoint_groups_by_type(trackpoint_groups()) :: trackpoint_groups()
  def recombine_trackpoint_groups_by_type([]), do: []

  def recombine_trackpoint_groups_by_type(trackpoint_groups) do
    trackpoint_groups
    |> Stream.chunk_while([], &recombine_step/2, &recombine_after/1)
  end

  defp recombine_step(elem, []), do: {:cont, elem}

  defp recombine_step({group_type, trkpts}, {group_type_acc, trkpts_acc}) do
    if group_type == group_type_acc do
      {:cont, {group_type_acc, trkpts_acc ++ trkpts}}
    else
      {:cont, {group_type_acc, trkpts_acc}, {group_type, trkpts}}
    end
  end

  defp recombine_after({group_type, trkpts}), do: {:cont, {group_type, trkpts}, nil}

  @doc """
  Apply the centerpoint to stop groups.
  ## Parameters
  - trackpoint_groups: The list of trackpoint groups to process.
  ## Examples
      iex> trackpoint_groups = [
      ...>   {:go, [trackpoint1, trackpoint2]},
      ...>   {:stop, [trackpoint3, trackpoint4]}
      ...> ]
      iex> apply_centerpoint_to_stop_groups(trackpoint_groups) |> Enum.to_list()
      [
        {:go, [trackpoint1, trackpoint2]},
        {:stop, [trackpoint3, trackpoint4], centerpoint}
      ]
  """
  @spec apply_centerpoint_to_stop_groups(trackpoint_groups()) :: trackpoint_groups()
  def apply_centerpoint_to_stop_groups(trackpoint_groups) do
    trackpoint_groups
    |> Stream.map(fn
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
    |> Enum.map(&apply_assumed_step(&1, factor, speed))
    |> List.flatten()
  end

  defp apply_assumed_step([{:go, [] = _go_trkpts} = p, _], _factor, _speed), do: p

  # Handles each incoming list of trackpoint groups, in pairs, except the last.
  defp apply_assumed_step(
         [{:go, go_trkpts}, {:stop, _stop_trkpts, {lon, lat} = _ctrpt}],
         factor,
         speed
       )
       when factor >= 0 do
    # Assume travel from last trackpoint in go group to centerpoint in stop group
    {:go,
     go_trkpts ++
       [
         %Trackpoint{
           lon: lon,
           lat: lat,
           time:
             estimate_time_based_on_speed(
               List.last(go_trkpts),
               %{lon: lon, lat: lat},
               factor,
               speed
             )
         }
       ]}
  end

  defp apply_assumed_step(
         [{:go, go_trkpts}, {:stop, _stop_trkpts, {lon, lat} = _ctrpt}],
         factor,
         speed
       )
       when factor < 0 do
    # Assume travel from last trackpoint in go group to centerpoint in stop group
    {:go,
     [
       %Trackpoint{
         lon: lon,
         lat: lat,
         time:
           estimate_time_based_on_speed(
             List.first(go_trkpts),
             %{lon: lon, lat: lat},
             factor,
             speed
           )
       }
     ] ++ go_trkpts}
  end

  defp apply_assumed_step([{:stop, _stop_trkpts, _ctrpt} = p, _], _factor, _speed), do: p
  defp apply_assumed_step([p], _factor, _speed), do: p

  @doc """
  Filter go groups from a list of trackpoint groups.
  ## Parameters
  - trackpoint_groups: The list of trackpoint groups to process.
  ## Examples
      iex> trackpoint_groups = [
      ...>   {:go, [trackpoint1, trackpoint2]},
      ...>   {:stop, [trackpoint3, trackpoint4]}
      ...> ]
      iex> filter_go_groups(trackpoint_groups)
      [{:go, [trackpoint1, trackpoint2]}]
  """
  @spec filter_go_groups(trackpoint_groups()) :: trackpoint_groups()
  def filter_go_groups(trackpoint_groups) do
    trackpoint_groups
    |> Stream.filter(&is_go_group/1)
  end

  defp is_go_group({:go, _trkpts}), do: true
  defp is_go_group(_), do: false

  @spec filter_stop_groups(trackpoint_groups()) :: trackpoint_groups()
  def filter_stop_groups(trackpoint_groups) do
    trackpoint_groups
    |> Stream.filter(&is_stop_group/1)
  end

  defp is_stop_group({:stop, _trkpts}), do: true
  defp is_stop_group({:stop, _trkpts, _ctrpt}), do: true
  defp is_stop_group(_), do: false

  defp emit_sorted_trackpoints({:go, trkpts}) do
    trkpts
    |> Enum.sort(&(DateTime.to_unix(&1.time) < DateTime.to_unix(&2.time)))
  end

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

  @doc """
  Calculate the datetime of a list of trackpoints.
  ## Parameters
  - trackpoints: The list of trackpoints to process.
  ## Examples
      iex> trackpoints = [
      ...>   %Trackpoint{time: DateTime.utc_now()},
      ...>   %Trackpoint{time: DateTime.add(DateTime.utc_now(), 2)}
      ...> ]
      iex> datetime_of_trackpoints(trackpoints)
      %DateTime{...}
  """
  def datetime_of_trackpoints([%{time: first} | _] = trackpoints) do
    last = List.last(trackpoints).time
    seconds_diff = DateTime.diff(last, first, :second)
    DateTime.add(first, div(seconds_diff, 2), :second)
  end

  @doc """
  Calculate the elevation of a list of trackpoints.
  ## Parameters
  - trackpoints: The list of trackpoints to process.
  ## Examples
      iex> trackpoints = [
      ...>   %Trackpoint{ele: 100.0},
      ...>   %Trackpoint{ele: 200.0}
      ...> ]
      iex> elevation_of_trackpoints(trackpoints)
      150.0
  """
  @spec elevation_of_trackpoints(trackpoints()) :: float()
  def elevation_of_trackpoints([]), do: nil

  def elevation_of_trackpoints(trackpoints) do
    trackpoints = trackpoints |> Enum.filter(&(&1.ele != nil))

    if length(trackpoints) == 0 do
      nil
    else
      trackpoints
      |> Enum.map(& &1.ele)
      |> Enum.reduce(&Kernel.+/2)
      |> Kernel./(length(trackpoints))
    end
  end

  @doc """
  Estimate the time of a trackpoint based on an assumed speed between two points.
  ## Parameters
  - trkpt1: The first trackpoint.
  - trkpt2: The second trackpoint.
  - factor: The factor to apply to the travel time (an integer, usually 1 or -1).
  - speed: The speed to use for the travel time calculation.
  ## Examples
      iex> trkpt1 = %Trackpoint{time: DateTime.utc_now(), lat: 40.1, lon: -105.1}
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
        %{time: time, lat: _, lon: _} = trkpt1,
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
