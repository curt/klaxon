defmodule GeoConverterTest do
  use ExUnit.Case, async: true
  alias GeoConverter

  describe "to_dms/2" do
    test "converts coordinates to DMS format" do
      assert GeoConverter.to_dms({-123.456, 45.678}, 2) ==
               {{123, 27, 21.6, :west}, {45, 40, 40.8, :north}}
    end

    test "handles zero coordinates" do
      assert GeoConverter.to_dms({0.0, 0.0}, 2) == {{0, 0, 0.0, nil}, {0, 0, 0.0, nil}}
    end

    test "handles positive coordinates" do
      assert GeoConverter.to_dms({123.456, -45.678}, 2) ==
               {{123, 27, 21.6, :east}, {45, 40, 40.8, :south}}
    end

    test "handles negative coordinates" do
      assert GeoConverter.to_dms({-123.456, -45.678}, 2) ==
               {{123, 27, 21.6, :west}, {45, 40, 40.8, :south}}
    end

    test "handles coordinates with different precisions" do
      assert GeoConverter.to_dms({123.456789, 45.678901}, 4) ==
               {{123, 27, 24.4404, :east}, {45, 40, 44.0436, :north}}
    end

    test "handles coordinates with no direction" do
      assert GeoConverter.to_dms({0.0, 0.0}, 2) == {{0, 0, 0.0, nil}, {0, 0, 0.0, nil}}
    end

    test "handles coordinates with only one axis" do
      assert GeoConverter.to_dms({123.456, 0.0}, 2) ==
               {{123, 27, 21.6, :east}, {0, 0, 0.0, nil}}

      assert GeoConverter.to_dms({0.0, -45.678}, 2) ==
               {{0, 0, 0.0, nil}, {45, 40, 40.8, :south}}
    end

    test "handles coordinates with both axes zero" do
      assert GeoConverter.to_dms({0.0, 0.0}, 2) == {{0, 0, 0.0, nil}, {0, 0, 0.0, nil}}
    end
  end
end
