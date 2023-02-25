defmodule KlaxonWeb.Helpers do
  @moduledoc """
  Provides helper functions for web app.
  """

  @doc """
  Returns `Map` with ActivityStream `@context` key and appropriate value.
  """
  @spec contextify() :: map
  def contextify() do
    %{"@context": "https://www.w3.org/ns/activitystreams"}
  end

  # @doc """
  # Puts ActivityStream `@context` key with
  # appropriate value onto given object.
  # """
  # @spec contextify(map) :: map
  # def contextify(%{} = object) do
  #   Map.put(object, "@context", "https://www.w3.org/ns/activitystreams")
  # end

  # def mergify(%{} = object, _key, nil) do
  #   object
  # end

  # def mergify(%{} = object, key, val) do
  #   Map.put(object, key, val)
  # end

  def prettify_date(date) do
    Timex.format!(date, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")
  end

  def prettify_date(date, :short) do
    Timex.format!(date, "{YYYY}-{0M}-{0D}")
  end

  @doc """
  Returns a datetime in a format suitable for the HTML `time` element.

  See: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/time
  """
  @spec htmlify_date(Timex.Types.valid_datetime) :: String.t()
  def htmlify_date(date) do
    Timex.format!(date, "{YYYY}-{0M}-{0D}T{h24}:{m}:{s}{Z:}")
  end

  @doc """
  Returns the git revision set in the application configuration.
  """
  @spec git_revision :: String.t() | nil
  def git_revision() do
    case Application.fetch_env(:klaxon, :git) do
      {:ok, keys} -> Keyword.get(keys, :revision)
      _ -> nil
    end
  end

  def json_status_response(conn, status, msg) do
    conn |> Plug.Conn.put_status(status) |> Phoenix.Controller.json(msg)
  end
end
