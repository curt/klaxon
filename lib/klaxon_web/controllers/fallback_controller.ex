defmodule KlaxonWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use KlaxonWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(KlaxonWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  # Handles an accepted request.
  # This is not an error, but the response has no payload.
  def call(conn, {:accepted}) do
    call_with_status(conn, :accepted, :"202")
  end

  # Handles a bad request.
  def call(conn, {:error, :bad_request}) do
    call_with_status(conn, :bad_request, :"400")
  end

  # Handles an unauthorized request.
  def call(conn, {:error, :unauthorized}) do
    call_with_status(conn, :unauthorized, :"401")
  end

  # Handles a not found request.
  def call(conn, {:error, :not_found}) do
    call_with_status(conn, :not_found, :"404")
  end

  # Handles a not acceptable request.
  def call(conn, {:error, :not_acceptable}) do
    call_with_status(conn, :not_acceptable, :"406")
  end

  # Handles a no profile request.
  def call(conn, {:error, :no_profile}) do
    call_with_status(conn, :service_unavailable, :no_profile)
  end

  defp call_with_status(conn, status, status_code) do
    conn
    |> put_status(status)
    |> put_root_layout(false)
    |> put_layout(false)
    |> put_view(KlaxonWeb.ErrorView)
    |> render("#{status_code}.#{get_format(conn)}")
  end
end
