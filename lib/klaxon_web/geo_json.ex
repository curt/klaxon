defmodule KlaxonWeb.GeoJson do
  def feature_collection(features) when is_list(features) do
    %{
      "type" => "FeatureCollection",
      "features" => features
    }
  end

  def feature(geometry, properties \\ nil) when is_map(geometry) do
    Map.merge(
      %{
        "type" => "Feature",
        "geometry" => geometry
      },
      if properties do
        %{"properties" => properties}
      else
        %{}
      end
    )
  end

  def point(coordinates) when is_list(coordinates) do
    %{
      "type" => "Point",
      "coordinates" => coordinates
    }
  end

  def line_string(coordinates) when is_list(coordinates) do
    %{
      "type" => "LineString",
      "coordinates" => coordinates
    }
  end
end
