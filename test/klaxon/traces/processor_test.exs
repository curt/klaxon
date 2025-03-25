defmodule Klaxon.Traces.ProcessorTest do
  use ExUnit.Case, async: true
  alias Klaxon.Traces.Processor
  alias Klaxon.Traces.Trace
  alias Klaxon.Traces.Track
  alias Klaxon.Traces.Segment
  alias Klaxon.Traces.Trackpoint
  alias Klaxon.Traces.Waypoint

  describe "preprocess_trace/2" do
    test "keeps empty trace" do
      trace = %Trace{tracks: [], waypoints: []}
      preprocessed = Processor.preprocess_trace(trace)
      assert length(preprocessed.tracks) == 0
    end

    test "keeps trackpoints" do
      now = DateTime.utc_now()

      trace = %Trace{
        tracks: [
          %Track{
            segments: [
              %Segment{
                trackpoints: [
                  %Trackpoint{lat: 40.2, lon: -105.2, created_at: now},
                  %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(now, 1200)}
                ]
              }
            ]
          }
        ],
        waypoints: []
      }

      preprocessed = Processor.preprocess_trace(trace)
      assert length(preprocessed.tracks) == 1
      first_track = List.first(preprocessed.tracks)
      assert length(first_track.segments) == 1
      first_segment = List.first(first_track.segments)
      assert length(first_segment.trackpoints) == 2
    end
  end

  describe "filter_trackpoints/3" do
    test "keeps empty list" do
      trackpoints = []
      filtered = Processor.filter_trackpoints(trackpoints, 5, 10)
      assert length(filtered) == 0
    end

    test "keeps only trackpoint" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
      ]

      filtered = Processor.filter_trackpoints(trackpoints, 5, 10)
      assert length(filtered) == 1
      assert Enum.each(filtered, fn trkpt -> is_struct(trkpt) end)
    end

    test "keeps last trackpoint even if it does not meet time or distance requirement" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 2)}
      ]

      filtered = Processor.filter_trackpoints(trackpoints, 5, 10)
      assert length(filtered) == 2
      assert Enum.each(filtered, fn trkpt -> is_struct(trkpt) end)
    end

    test "discards trackpoint that does not meet time or distance requirement" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 2)},
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 4)}
      ]

      filtered = Processor.filter_trackpoints(trackpoints, 5, 10)
      assert length(filtered) == 2
      assert Enum.each(filtered, fn trkpt -> is_struct(trkpt) end)
    end

    test "retains trackpoint that does meet time requirement" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 6)},
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 7)}
      ]

      filtered = Processor.filter_trackpoints(trackpoints, 5, 10)
      assert length(filtered) == 3
      assert Enum.each(filtered, fn trkpt -> is_struct(trkpt) end)
    end

    test "retains trackpoint that does meet distance requirement" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
        %Trackpoint{lat: 40.1, lon: -105.2, created_at: DateTime.add(DateTime.utc_now(), 2)},
        %Trackpoint{lat: 40.1, lon: -105.2, created_at: DateTime.add(DateTime.utc_now(), 4)}
      ]

      filtered = Processor.filter_trackpoints(trackpoints, 5, 10)
      assert length(filtered) == 3
      assert Enum.each(filtered, fn trkpt -> is_struct(trkpt) end)
    end
  end

  describe "process_trace/2" do
    test "keeps empty trace" do
      trace = %Trace{tracks: [], waypoints: []}
      processed = Processor.process_trace(trace)
      assert length(processed.tracks) == 0
    end

    test "keeps trackpoints" do
      now = DateTime.utc_now()

      trace = %Trace{
        tracks: [
          %Track{
            segments: [
              %Segment{
                trackpoints: [
                  %Trackpoint{lat: 40.2, lon: -105.2, created_at: now},
                  %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(now, 1200)}
                ]
              }
            ]
          }
        ],
        waypoints: [%Waypoint{lat: 40.1, lon: -105.1, created_at: now}]
      }

      processed = Processor.process_trace(trace)
      assert length(processed.tracks) == 1
      first_track = List.first(processed.tracks)
      assert length(first_track.segments) == 1
      first_segment = List.first(first_track.segments)
      assert length(first_segment.trackpoints) == 2
      assert length(processed.waypoints) == 1
    end

    test "obvioous stop splits segment and adds waypoint" do
      now = DateTime.utc_now()

      trace = %Trace{
        tracks: [
          %Track{
            segments: [
              %Segment{
                trackpoints: [
                  %Trackpoint{lat: 40.2, lon: -105.2, created_at: now},
                  %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(now, 200)},
                  %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(now, 3200)},
                  %Trackpoint{lat: 40.0, lon: -105.0, created_at: DateTime.add(now, 3400)}
                ]
              }
            ]
          }
        ],
        waypoints: [%Waypoint{lat: 40.1, lon: -105.1, created_at: now}]
      }

      processed = Processor.process_trace(trace)
      assert length(processed.tracks) == 1
      first_track = List.first(processed.tracks)
      assert length(first_track.segments) == 2
      first_segment = List.first(first_track.segments)
      assert length(first_segment.trackpoints) == 2
      assert length(processed.waypoints) == 2
    end
  end

  describe "process_trackpoints/2" do
    test "keeps empty list" do
      trackpoints = []
      {processed, _} = Processor.process_trackpoints(trackpoints)
      assert length(processed) == 0
    end

    test "returns single trackpoint" do
      now = DateTime.utc_now()

      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: now}
      ]

      {processed, _} = Processor.process_trackpoints(trackpoints)
      assert length(processed) == 1
      assert [%Trackpoint{}] = trkpts = Enum.at(processed, 0)
      assert trkpt = Enum.at(trkpts, 0)
      assert trkpt.lat == 40.1
      assert trkpt.lon == -105.1
      assert trkpt.created_at == now
    end

    test "correctly handles obvious stop" do
      now = DateTime.utc_now()

      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, created_at: now},
        %Trackpoint{lat: 40.15, lon: -105.15, created_at: DateTime.add(now, 200)},
        %Trackpoint{lat: 40.2, lon: -105.2, created_at: DateTime.add(now, 400)},
        %Trackpoint{lat: 40.2, lon: -105.2, created_at: DateTime.add(now, 2400)},
        %Trackpoint{lat: 40.25, lon: -105.25, created_at: DateTime.add(now, 2600)},
        %Trackpoint{lat: 40.3, lon: -105.3, created_at: DateTime.add(now, 2800)}
      ]

      {processed, waypts} =
        Processor.process_trackpoints(trackpoints, radius: 0.1, duration: 800, speed: 100.0)

      assert length(processed) == 2
      trkpts0 = Enum.at(processed, 0)
      trkpt00 = Enum.at(trkpts0, 0)
      assert trkpt00.lat == 40.1
      assert trkpt00.lon == -105.1
      assert trkpt00.created_at == now
      trkpt01 = Enum.at(trkpts0, 1)
      assert trkpt01.lat == 40.15
      assert trkpt01.lon == -105.15
      trkpts1 = Enum.at(processed, 1)
      trkpt10 = Enum.at(trkpts1, 0)
      assert trkpt10.lat == 40.2
      assert trkpt10.lon == -105.2
      assert DateTime.diff(now, trkpt10.created_at) < 2600
      trkpt11 = Enum.at(trkpts1, 1)
      assert trkpt11.lat == 40.25
      assert trkpt11.lon == -105.25

      assert length(waypts) == 1
      assert %Waypoint{} = waypt = Enum.at(waypts, 0)
      assert waypt.lat == 40.2
      assert waypt.lon == -105.2
      assert waypt.created_at == DateTime.add(now, 1400)
    end
  end

  describe "chunk_trackpoints_by_radius/2" do
    test "splits tracks into chunks based on distance, single chunk, all go" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1},
        %Trackpoint{lat: 40.2, lon: -105.2},
        %Trackpoint{lat: 40.3, lon: -105.3},
        %Trackpoint{lat: 40.4, lon: -105.4}
      ]

      results = Processor.chunk_trackpoints_by_radius(trackpoints, 0.1)
      assert length(results) == 1
      assert {:go, _} = Enum.at(results, 0)
    end

    test "splits tracks into chunks based on distance, two chunks, go then stop" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1},
        %Trackpoint{lat: 40.2, lon: -105.2},
        %Trackpoint{lat: 40.2, lon: -105.2},
        %Trackpoint{lat: 40.2, lon: -105.2}
      ]

      results = Processor.chunk_trackpoints_by_radius(trackpoints, 0.1)
      assert length(results) == 2
      assert {:go, _} = Enum.at(results, 0)
      assert {:stop, _} = Enum.at(results, 1)
    end

    test "splits tracks into chunks based on distance, three chunks, go-stop-go" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1},
        %Trackpoint{lat: 40.2, lon: -105.2},
        %Trackpoint{lat: 40.2, lon: -105.2},
        %Trackpoint{lat: 40.3, lon: -105.3}
      ]

      results = Processor.chunk_trackpoints_by_radius(trackpoints, 0.1)
      assert length(results) == 3
      assert {:go, _} = Enum.at(results, 0)
      assert {:stop, _} = Enum.at(results, 1)
      assert {:go, _} = Enum.at(results, 2)
    end
  end

  describe "remap_trackpoint_groups_by_duration/2" do
    test "remaps single go group" do
      trackpoints = [
        {:go,
         [
           %Trackpoint{lat: 40.1, lon: -105.1},
           %Trackpoint{lat: 40.2, lon: -105.2},
           %Trackpoint{lat: 40.3, lon: -105.3},
           %Trackpoint{lat: 40.4, lon: -105.4}
         ]}
      ]

      results = Processor.remap_trackpoint_groups_by_duration(trackpoints, 300)
      assert length(results) == 1
      assert {:go, _} = Enum.at(results, 0)
    end

    test "remaps stop group to go based on length" do
      trackpoints = [
        {:stop,
         [
           %Trackpoint{lat: 40.1, lon: -105.1}
         ]}
      ]

      results = Processor.remap_trackpoint_groups_by_duration(trackpoints, 1200)
      assert length(results) == 1
      {:go, trkpts} = Enum.at(results, 0)
      assert length(trkpts) == 1
    end

    test "remaps stop group to go based on duration" do
      trackpoints = [
        {:stop,
         [
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 800)}
         ]}
      ]

      results = Processor.remap_trackpoint_groups_by_duration(trackpoints, 1200)
      assert length(results) == 1
      {:go, trkpts} = Enum.at(results, 0)
      assert length(trkpts) == 2
    end

    test "retains stop group based on duration" do
      trackpoints = [
        {:stop,
         [
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()},
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 400)},
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.add(DateTime.utc_now(), 800)}
         ]}
      ]

      results = Processor.remap_trackpoint_groups_by_duration(trackpoints, 600)
      assert length(results) == 1
      {:stop, trkpts} = Enum.at(results, 0)
      assert length(trkpts) == 3
    end

    test "remaps all groups to go" do
      trackpoints = [
        {:go,
         [
           %Trackpoint{lat: 40.1, lon: -105.1},
           %Trackpoint{lat: 40.2, lon: -105.2},
           %Trackpoint{lat: 40.3, lon: -105.3}
         ]},
        {:stop,
         [
           %Trackpoint{lat: 40.4, lon: -105.4}
         ]},
        {:go,
         [
           %Trackpoint{lat: 40.5, lon: -105.5},
           %Trackpoint{lat: 40.6, lon: -105.6}
         ]}
      ]

      results = Processor.remap_trackpoint_groups_by_duration(trackpoints, 600)
      assert length(results) == 3
      assert Enum.all?(results, fn {:go, _} -> true end)
    end
  end

  describe "recombine_trackpoint_groups_by_type" do
    test "recombines all go groups" do
      trackpoints = [
        {:go,
         [
           %Trackpoint{lat: 40.1, lon: -105.1},
           %Trackpoint{lat: 40.2, lon: -105.2},
           %Trackpoint{lat: 40.3, lon: -105.3}
         ]},
        {:go,
         [
           %Trackpoint{lat: 40.4, lon: -105.4},
           %Trackpoint{lat: 40.5, lon: -105.5}
         ]}
      ]

      results = Processor.recombine_trackpoint_groups_by_type(trackpoints)

      assert length(results) == 1
      {:go, trkpts} = Enum.at(results, 0)
      assert length(trkpts) == 5
      assert Enum.at(trkpts, 0).lat == 40.1
      assert Enum.at(trkpts, 4).lat == 40.5
    end
  end

  describe "apply_centerpoint_to_stop_groups/1" do
    test "applies centerpoint to stop group" do
      trackpoints = [
        {:stop,
         [
           %Trackpoint{lat: 40.1, lon: -105.1},
           %Trackpoint{lat: 40.2, lon: -105.2},
           %Trackpoint{lat: 40.3, lon: -105.3}
         ]},
        {:go,
         [
           %Trackpoint{lat: 40.4, lon: -105.4}
         ]}
      ]

      results = Processor.apply_centerpoint_to_stop_groups(trackpoints)
      assert length(results) == 2
      {:stop, trkpts, {lon, lat} = _ctrpt} = Enum.at(results, 0)
      assert length(trkpts) == 3
      assert lon < -105.1 and lon > -105.3
      assert lat > 40.1 and lat < 40.3
    end
  end

  describe "estimate_time_based_on_speed/4" do
    test "estimates time based on speed, forward" do
      start = %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
      stop = %Trackpoint{lat: 40.2, lon: -105.2}
      speed = 1.0

      time = Processor.estimate_time_based_on_speed(start, stop, 1, speed)
      assert DateTime.diff(time, start.created_at) > 0
    end

    test "estimates time based on speed, back" do
      stop = %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
      start = %Trackpoint{lat: 40.2, lon: -105.2}
      speed = 1.0

      time = Processor.estimate_time_based_on_speed(stop, start, -1, speed)
      assert DateTime.diff(time, stop.created_at) < 0
    end
  end

  describe "apply_assumed_trackpoints/1" do
    test "applies assumed trackpoints to stop group" do
      now = DateTime.utc_now()

      groups = [
        {:go,
         [
           %Trackpoint{lon: -105.1, lat: 40.1, created_at: now},
           %Trackpoint{lon: -105.14, lat: 40.14, created_at: DateTime.add(now, 200)},
           %Trackpoint{lon: -105.17, lat: 40.17, created_at: DateTime.add(now, 400)}
         ]},
        {:stop,
         [
           %Trackpoint{lon: -105.2, lat: 40.2, created_at: DateTime.add(now, 2400)}
         ], {-105.2, 40.2}},
        {:go,
         [
           %Trackpoint{lon: -105.23, lat: 40.23, created_at: DateTime.add(now, 4400)},
           %Trackpoint{lon: -105.26, lat: 40.26, created_at: DateTime.add(now, 4600)},
           %Trackpoint{lon: -105.3, lat: 40.3, created_at: DateTime.add(now, 4800)}
         ]}
      ]

      results0 = groups |> Processor.apply_assumed_trackpoints(1)
      assert length(results0) == 3

      {:go, go_trkpts0} = Enum.at(results0, 0)
      assert length(go_trkpts0) == 4
      last_go_trkpt0 = List.last(go_trkpts0)
      assert %{lon: _, lat: _, created_at: last_go_created_at} = last_go_trkpt0
      assert DateTime.diff(last_go_created_at, now) > 400

      results1 =
        results0 |> Enum.reverse() |> Processor.apply_assumed_trackpoints(-1) |> Enum.reverse()

      {:go, go_trkpts2} = Enum.at(results1, 2)
      assert length(go_trkpts2) == 4
      first_go_trkpt2 = List.first(go_trkpts2)
      assert %{lat: 40.2, lon: -105.2, created_at: first_go_created_at} = first_go_trkpt2
      assert DateTime.diff(first_go_created_at, now) < 4400
    end
  end

  describe "filter_go_groups/1" do
    test "filters go groups, empty list" do
      groups = []

      results = Processor.filter_go_groups(groups)
      assert length(results) == 0
    end

    test "filters go groups, one stop group" do
      groups = [
        {:stop,
         [
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
         ], {40.1, -105.1}}
      ]

      results = Processor.filter_go_groups(groups)
      assert length(results) == 0
    end

    test "filters go groups, one stop group, one go group" do
      groups = [
        {:go,
         [
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
         ]},
        {:stop,
         [
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
         ], {40.1, -105.1}}
      ]

      results = Processor.filter_go_groups(groups)
      assert length(results) == 1
      {:go, go_trkpts} = Enum.at(results, 0)
      assert length(go_trkpts) == 1
    end
  end

  describe "filter_stop_groups/1" do
    test "filters stop groups, empty list" do
      groups = []

      results = Processor.filter_stop_groups(groups)
      assert length(results) == 0
    end

    test "filters stop groups, one go group" do
      groups = [
        {:go,
         [
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
         ]}
      ]

      results = Processor.filter_stop_groups(groups)
      assert length(results) == 0
    end

    test "filters stop groups, one go group, one stop group" do
      groups = [
        {:go,
         [
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
         ]},
        {:stop,
         [
           %Trackpoint{lat: 40.1, lon: -105.1, created_at: DateTime.utc_now()}
         ], {40.1, -105.1}}
      ]

      results = Processor.filter_stop_groups(groups)
      assert length(results) == 1
      {:stop, stop_trkpts, {lat, lon}} = Enum.at(results, 0)
      assert length(stop_trkpts) == 1
      assert lat == 40.1
      assert lon == -105.1
    end
  end

  describe "elevation_of_trackpoints/1" do
    test "returns nil for empty list" do
      trackpoints = []

      assert Processor.elevation_of_trackpoints(trackpoints) == nil
    end

    test "returns nil for trackpoints without elevation" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1}
      ]

      assert Processor.elevation_of_trackpoints(trackpoints) == nil
    end

    test "returns elevation of single trackpoint" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, ele: 100.0}
      ]

      assert Processor.elevation_of_trackpoints(trackpoints) == 100.0
    end

    test "returns elevation of mulitple trackpoints, weighted average" do
      trackpoints = [
        %Trackpoint{lat: 40.1, lon: -105.1, ele: 100.0},
        %Trackpoint{lat: 40.2, lon: -105.2, ele: 100.0},
        %Trackpoint{lat: 40.3, lon: -105.3, ele: 190.0}
      ]

      assert Processor.elevation_of_trackpoints(trackpoints) == 130.0
    end
  end
end
