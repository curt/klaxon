defmodule KlaxonWeb.Helpers.GoogleMaps do
  alias GeoConverter

  def place_uri(%{lon: lon, lat: lat} = coords) do
    "https://www.google.com/maps/place/#{place_name(coords)}/@#{lat},#{lon},19z"
    |> URI.encode()
  end

  def place_uri(_), do: nil

  def place_name(%{lon: _lon, lat: _lat} = coords) do
    coords
    |> GeoConverter.to_dms(1)
    |> format_name()
  end

  defp format_name({lon, lat} = _dms) do
    "#{format_name_part(lat, :lat)} #{format_name_part(lon, :lon)}"
  end

  defp format_name_part({degrees, minutes, seconds, direction} = _dmspart, axis) do
    "#{degrees}°#{pad_min(minutes)}'#{pad_sec(seconds)}\"#{direction(axis, direction)}"
  end

  defp pad_min(value), do: String.pad_leading(Integer.to_string(value), 2, "0")
  defp pad_sec(value), do: String.pad_leading(Float.to_string(value), 4, "0")

  defp direction(:lon, nil), do: "E"
  defp direction(:lon, :east), do: "E"
  defp direction(:lon, :west), do: "W"
  defp direction(:lat, nil), do: "N"
  defp direction(:lat, :north), do: "N"
  defp direction(:lat, :south), do: "S"
end
