defmodule KlaxonWeb.Plugs.CacheControl do
  @moduledoc """
  A plug that sets HTTP cache headers based on the cache level assigned to a route.

  This plug reads the `:cache` assign from `conn.assigns`, maps it to a cache duration
  configured in `config.exs`, and applies the appropriate `Cache-Control` and `Expires` headers.

  ## Cache Levels
  The cache levels and their corresponding durations are configured in `config.exs` under:

      config :klaxon, KlaxonWeb.CacheConfig,
        cache_durations: %{
          none: 0,
          gentle: 60,        # 1 minute
          moderate: 300,     # 5 minutes
          aggressive: 3600,  # 1 hour
          static: 31_536_000 # 1 year
        }

  ## Usage
  Add the plug to a pipeline in your `router.ex`:

      pipeline :cache_control do
        plug KlaxonWeb.Plugs.CacheControl
      end

  Or apply it directly within a scope:

      scope "/", KlaxonWeb do
        pipe_through :browser

        plug KlaxonWeb.Plugs.CacheControl

        get "/news", NewsController, :index, assigns: %{cache: :moderate}
        get "/profile", ProfileController, :show, assigns: %{cache: :none}
        get "/static-page", PageController, :show, assigns: %{cache: :static}
      end
  """
  import Plug.Conn

  @config Application.compile_env(:klaxon, KlaxonWeb.CacheConfig)

  @typedoc "Cache level options"
  @type cache_level :: :none | :gentle | :moderate | :aggressive | :static

  @typedoc "The cache duration in seconds"
  @type cache_duration :: non_neg_integer()

  @doc """
  Initializes the plug with default options.

  This plug does not require any options, so the argument is ignored.
  """
  @spec init(any()) :: any()
  def init(default), do: default

  @doc """
  Sets cache headers on the connection based on the `:cache` assign.

  If no `:cache` assign is found, the default level `:none` is used.

  ## Example
      conn = %Plug.Conn{assigns: %{cache: :moderate}}
      conn = KlaxonWeb.Plugs.CacheControl.call(conn, [])
  """
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    cache_level = conn.assigns[:cache] || :none
    cache_duration = Map.get(@config[:cache_durations], cache_level, 0)

    conn
    |> put_cache_headers(cache_duration)
  end

  defp put_cache_headers(conn, 0) do
    conn
    |> put_resp_header("cache-control", "no-store, no-cache, must-revalidate, max-age=0")
    |> put_resp_header("expires", "0")
  end

  defp put_cache_headers(conn, seconds) do
    conn
    |> put_resp_header("cache-control", "public, max-age=#{seconds}")
    |> put_resp_header("expires", http_date(seconds))
  end

  defp http_date(seconds) do
    DateTime.utc_now()
    |> DateTime.add(seconds, :second)
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end
end
