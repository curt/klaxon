defmodule KlaxonWeb.Helpers.GoogleMapsTest do
  use ExUnit.Case, async: true
  alias KlaxonWeb.Helpers.GoogleMaps

  describe "place_name/1" do
    test "formats coordinates correctly" do
      coords = %{lon: -123.456, lat: 45.678}
      expected = "45°40'40.8\"N 123°27'21.6\"W"
      assert GoogleMaps.place_name(coords) == expected
    end

    test "handles zero coordinates" do
      coords = %{lon: 0.0, lat: 0.0}
      expected = "0°00'00.0\"N 0°00'00.0\"E"
      assert GoogleMaps.place_name(coords) == expected
    end

    test "handles positive coordinates" do
      coords = %{lon: 123.456, lat: -45.678}
      expected = "45°40'40.8\"S 123°27'21.6\"E"
      assert GoogleMaps.place_name(coords) == expected
    end

    test "handles negative coordinates" do
      coords = %{lon: -123.456, lat: -45.678}
      expected = "45°40'40.8\"S 123°27'21.6\"W"
      assert GoogleMaps.place_name(coords) == expected
    end

    test "handles coordinates with different precisions" do
      coords = %{lon: 123.456789, lat: 45.678901}
      expected = "45°40'44.0\"N 123°27'24.4\"E"
      assert GoogleMaps.place_name(coords) == expected
    end

    test "handles coordinates with no direction" do
      coords = %{lon: 0.0, lat: 0.0}
      expected = "0°00'00.0\"N 0°00'00.0\"E"
      assert GoogleMaps.place_name(coords) == expected
    end

    test "handles coordinates with only one axis" do
      coords1 = %{lon: 123.456, lat: 0.0}
      expected1 = "0°00'00.0\"N 123°27'21.6\"E"
      assert GoogleMaps.place_name(coords1) == expected1

      coords2 = %{lon: 0.0, lat: -45.678}
      expected2 = "45°40'40.8\"S 0°00'00.0\"E"
      assert GoogleMaps.place_name(coords2) == expected2
    end
  end
end
