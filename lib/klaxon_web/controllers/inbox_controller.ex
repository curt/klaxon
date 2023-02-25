defmodule KlaxonWeb.InboxController do
  @moduledoc """
  Provides valid but empty controller responses. Allows definition of routes
  for which other controllers are not yet defined.
  """
  require Logger
  use KlaxonWeb, :controller
  import KlaxonWeb.Plugs
  alias Klaxon.Profiles.Profile
  alias Klaxon.Activities.Inbound

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def index(%Plug.Conn{private: %{:phoenix_format => "activity+json"}} = conn, _params) do
    render(conn, :index)
  end

  def index(_, _params) do
    {:error, :not_acceptable}
  end

  def create(%Plug.Conn{private: %{:phoenix_format => "activity+json"}} = conn, params) do
    with {:ok, _profile} <- get_profile(conn) do
      if Inbound.request_well_formed?(params, conn.req_headers) do
        Logger.info(
          "accepted inbox request\n params: #{inspect(params)}\n" <>
            "req_headers: #{inspect(conn.req_headers)}"
        )

        {:accepted}
      else
        {:error, :bad_request}
      end
    end
  end

  def create(_, _params) do
    {:error, :not_acceptable}
  end

  defp get_profile(conn) do
    case conn.assigns[:current_profile] do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end
end
