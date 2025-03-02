defmodule KlaxonWeb.Api.SessionController do
  use KlaxonWeb, :controller
  alias Klaxon.Auth
  alias KlaxonWeb.UserAuth

  def create(conn, %{"email" => email, "password" => password}) do
    case Auth.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json("Invalid email or password")

      user ->
        conn
        |> UserAuth.log_in_user_api(user)
        |> redirect(to: Routes.api_session_path(conn, :show))
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> json("Missing email or password")
  end

  def show(conn, _params) do
    conn
    |> json(%{user: conn.assigns.current_user, profile: conn.assigns.current_profile})
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user_api()
    |> put_status(:ok)
    |> json("Logged out")
  end
end
