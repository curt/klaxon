defmodule KlaxonWeb.Plugs.CacheControlTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias KlaxonWeb.Plugs.CacheControl

  @cache_durations %{
    none: 0,
    gentle: 60,
    moderate: 300,
    aggressive: 3_600,
    static: 31_536_000
  }

  setup do
    Application.put_env(:klaxon, KlaxonWeb.CacheConfig, cache_durations: @cache_durations)
    :ok
  end

  defp call_plug(assigns \\ %{}) do
    conn(:get, "/")
    |> Map.put(:assigns, assigns)
    |> CacheControl.call([])
  end

  test "sets no-store headers for :none cache level" do
    conn = call_plug(cache: :none)

    assert get_resp_header(conn, "cache-control") == [
             "no-store, no-cache, must-revalidate, max-age=0"
           ]

    assert get_resp_header(conn, "expires") == ["0"]
  end

  test "sets appropriate cache headers for :gentle cache level" do
    conn = call_plug(cache: :gentle)
    expected_max_age = @cache_durations[:gentle]

    assert get_resp_header(conn, "cache-control") == ["public, max-age=#{expected_max_age}"]
    assert_datetime_header(conn, expected_max_age)
  end

  test "sets appropriate cache headers for :moderate cache level" do
    conn = call_plug(cache: :moderate)
    expected_max_age = @cache_durations[:moderate]

    assert get_resp_header(conn, "cache-control") == ["public, max-age=#{expected_max_age}"]
    assert_datetime_header(conn, expected_max_age)
  end

  test "sets appropriate cache headers for :aggressive cache level" do
    conn = call_plug(cache: :aggressive)
    expected_max_age = @cache_durations[:aggressive]

    assert get_resp_header(conn, "cache-control") == ["public, max-age=#{expected_max_age}"]
    assert_datetime_header(conn, expected_max_age)
  end

  test "sets appropriate cache headers for :static cache level" do
    conn = call_plug(cache: :static)
    expected_max_age = @cache_durations[:static]

    assert get_resp_header(conn, "cache-control") == ["public, max-age=#{expected_max_age}"]
    assert_datetime_header(conn, expected_max_age)
  end

  test "defaults to :none when cache level is not set" do
    conn = call_plug()

    assert get_resp_header(conn, "cache-control") == [
             "no-store, no-cache, must-revalidate, max-age=0"
           ]

    assert get_resp_header(conn, "expires") == ["0"]
  end

  defp assert_datetime_header(conn, expected_seconds) do
    [expires_header] = get_resp_header(conn, "expires")

    expected_datetime =
      DateTime.utc_now()
      |> DateTime.add(expected_seconds, :second)
      |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")

    # Allow slight time difference due to execution time
    assert String.slice(expires_header, 0..19) == String.slice(expected_datetime, 0..19)
  end
end
