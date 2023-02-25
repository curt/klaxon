defmodule KlaxonWeb.EmptyController do
  @moduledoc """
  Provides valid but empty controller responses. Allows definition of routes
  for which other controllers are not yet defined.
  """
  use KlaxonWeb, :controller
  import KlaxonWeb.Plugs

  action_fallback KlaxonWeb.FallbackController
  plug :activity_json_response

  def show(%Plug.Conn{private: %{:phoenix_format => "activity+json"}} = conn, _params) do
    render(conn, :show)
  end

  def show(_, _params) do
    {:error, :not_acceptable}
  end
end
