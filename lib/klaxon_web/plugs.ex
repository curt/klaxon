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
  alias KlaxonWeb.Router.Helpers, as: Routes

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
    uri = Routes.profile_url(conn, :index)
    Logger.info("Fetching profile: #{uri}")

    case Profiles.get_local_profile_by_uri(uri) do
      {:ok, %Profile{} = profile} ->
        conn |> assign(:current_profile, profile)

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
  Assigns `:is_owner` to true if current_user owns current_profile.
  """
  @spec assign_owner_flag(Plug.Conn.t(), any) :: Plug.Conn.t()
  def assign_owner_flag(conn, _opts) do
    is_owner =
      conn.assigns[:current_profile] &&
        conn.assigns[:current_user] &&
        Profiles.is_profile_owned_by_user?(
          conn.assigns.current_profile,
          conn.assigns.current_user
        )

    assign(conn, :is_owner, is_owner)
  end

  @doc """
  Requires signed-in user to be principal of current profile.
  """
  @spec require_owner(Plug.Conn.t(), any) :: Plug.Conn.t()
  def require_owner(conn, _opts) do
    if conn.assigns[:is_owner] do
      conn
    else
      conn |> render_error_and_halt(:unauthorized, :"401")
    end
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
