defmodule KlaxonWeb.Plugs do
  @moduledoc """
  This module defines function plugs local to the `KlaxonWeb` application.

  See `Phoenix.Plug` for more information on function plugs.
  """
  import Plug.Conn
  import Phoenix.Controller
  alias Klaxon.Auth.User
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
  Fetches the `Klaxon.Profiles.Profile` associated with the requested host, scheme, and port.
  """
  @spec fetch_current_profile(Plug.Conn.t(), any) :: Plug.Conn.t()
  def fetch_current_profile(conn, _opts) do
    uri =
      %URI{host: conn.host, scheme: Atom.to_string(conn.scheme), port: conn.port, path: "/"}
      |> URI.to_string()

    case Profiles.get_local_profile_by_uri(uri) do
      {:ok, %Profile{} = profile} -> assign(conn, :current_profile, profile)
      _ -> conn
    end
  end

  @doc """
  Requires the signed-in `Klaxon.Auth.User` to be a `Klaxon.Profiles.Principal`
  of the current `Klaxon.Profiles.Profile`.
  """
  @spec require_principal(Plug.Conn.t(), any) :: Plug.Conn.t()
  def require_principal(conn, _opts) do
    case {conn.assigns[:current_profile], conn.assigns[:current_user]} do
      {%Profile{} = profile, %User{} = user} ->
        unless Profiles.is_profile_owned_by_user?(profile, user) do
          conn
          |> put_status(:unauthorized)
          |> put_view(KlaxonWeb.ErrorView)
          |> render(:"401")
          |> halt()
        else
          conn
        end

      _ ->
        conn
    end
  end
end
