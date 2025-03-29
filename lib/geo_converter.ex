defmodule GeoConverter do
  @type dms :: {integer(), integer(), float(), :north | :south | :east | :west | nil}

  @doc """
  Converts decimal coordinates to degrees, minutes, and seconds (DMS) format.
  The function takes a tuple of coordinates (longitude, latitude) or a map with
  `:lat` and `:lon` keys, and an integer representing the precision for seconds.
  The precision determines how many decimal places to include in the seconds
  value. The function returns a tuple of DMS coordinates in the format:
  `{degrees, minutes, seconds, direction}`.
  The direction is `:north`, `:south`, `:east`, or `:west` based on the sign of
  the decimal value. If the decimal value is zero, the direction is `nil`.
  The function handles both positive and negative coordinates, as well as zero
  coordinates. It also supports different precisions for the seconds value.
  For example:
  ```
  iex> GeoConverter.to_dms({-123.456, 45.678}, 2)
  {{123, 27, 21.6, :west}, {45, 40, 40.8, :north}}
  iex> GeoConverter.to_dms({0.0, 0.0}, 2)
  {{0, 0, 0.0, nil}, {0, 0, 0.0, nil}}
  ```
  The function can also be used with a map:
  ```
  iex> GeoConverter.to_dms(%{lon: -123.456, lat: 45.678}, 2)
  {{123, 27, 21.6, :west}, {45, 40, 40.8, :north}}
  ```
  The function is designed to be used in applications that require conversion
  of geographic coordinates from decimal format to DMS format, such as mapping
  applications, GPS systems, and geographic information systems (GIS).
  ## Parameters
  - `coordinates`: A tuple of coordinates `{longitude, latitude}` or a map
    with `:lat` and `:lon` keys.
  - `precision`: An integer representing the precision for seconds (number of
    decimal places).
  ## Returns
  - A tuple of DMS coordinates in the format:
    `{degrees, minutes, seconds, direction}`.
  The direction is `:north`, `:south`, `:east`, or `:west` based on the sign
  of the decimal value. If the decimal value is zero, the direction is `nil`.
  """

  @spec to_dms(
          {number(), number()} | %{:lat => number(), :lon => number()},
          integer()
        ) :: {dms(), dms()}
  def to_dms(%{lon: lon, lat: lat}, precision) do
    to_dms({lon, lat}, precision)
  end

  def to_dms({lon, lat}, precision) do
    {to_dms(lon, :lon, precision), to_dms(lat, :lat, precision)}
  end

  @spec to_dms(number(), any(), byte()) :: dms()
  def to_dms(decimal, axis, precision) do
    abs_decimal = abs(decimal)
    degrees = trunc(abs_decimal)
    minutes_float = (abs_decimal - degrees) * 60
    minutes = trunc(minutes_float)
    seconds = Float.round((minutes_float - minutes) * 60, precision)

    {degrees, minutes, seconds, direction(decimal, axis)}
  end

  defp direction(decimal, _) when decimal == 0, do: nil
  defp direction(decimal, :lat) when decimal > 0, do: :north
  defp direction(decimal, :lat) when decimal < 0, do: :south
  defp direction(decimal, :lon) when decimal > 0, do: :east
  defp direction(decimal, :lon) when decimal < 0, do: :west
end
