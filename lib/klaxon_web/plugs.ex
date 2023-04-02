defmodule KlaxonWeb.Plugs do
  @moduledoc """
  This module defines function plugs local to the `KlaxonWeb` application.

  See `Phoenix.Plug` for more information on function plugs.
  """
  require Logger
  import Plug.Conn
  import Phoenix.Controller
  alias Klaxon.Profiles
  alias Klaxon.Profiles.Profile

  @doc """
  Puts the `application/activity+json` content type on the response if the request was of a corresponding format.
  """
  @spec activity_json_response(Plug.Conn.t(), any) :: Plug.Conn.t()
  def activity_json_response(conn, _opts) do
    case conn.private[:phoenix_format] do
      "activity+json" -> put_resp_content_type(conn, "application/activity+json")
      _ -> conn
    end
  end

  @doc """
  Ignores incoming `accept` header, sends `application/activity+json` response content type.
  """
  @spec force_activity_json_response(Plug.Conn.t(), any) :: Plug.Conn.t()
  def force_activity_json_response(conn, _opts) do
    conn |> put_resp_content_type("application/activity+json")
  end

  @doc """
  Fetches current profile and endpoint associated with host, scheme, and port.
  Stores results in conn assigns.
  """
  @spec fetch_current_profile(Plug.Conn.t(), any) :: Plug.Conn.t()
  def fetch_current_profile(conn, _opts) do
    endpoint = %URI{host: conn.host, scheme: Atom.to_string(conn.scheme), port: conn.port}
    uri = endpoint |> Map.put(:path, "/") |> URI.to_string()
    Logger.info("Fetching profile: #{uri}")

    case Profiles.get_local_profile_by_uri(uri) do
      {:ok, %Profile{} = profile} ->
        conn |> assign(:current_profile, profile) |> assign(:current_endpoint, endpoint)

      _ ->
        conn
    end
  end

  @doc """
  Requires current profile.
  """
  @spec require_profile(Plug.Conn.t(), any) :: Plug.Conn.t()
  def require_profile(conn, _opts) do
    profile = conn.assigns[:current_profile]

    unless profile do
      conn |> render_error_and_halt(:service_unavailable, "no_profile.#{get_format(conn)}")
    end || conn
  end

  @doc """
  Requires signed-in user to be principal of current profile.
  """
  @spec require_principal(Plug.Conn.t(), any) :: Plug.Conn.t()
  def require_principal(conn, _opts) do
    profile = conn.assigns[:current_profile]
    user = conn.assigns[:current_user]

    unless profile && user && Profiles.is_profile_owned_by_user?(profile, user) do
      conn |> render_error_and_halt(:unauthorized, :"401")
    end || conn
  end

  defp render_error_and_halt(conn, status, template) do
    conn
    |> put_status(status)
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_view(KlaxonWeb.ErrorView)
    |> render(template)
    |> halt()
  end
end
