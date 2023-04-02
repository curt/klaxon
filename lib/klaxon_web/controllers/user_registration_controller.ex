defmodule KlaxonWeb.UserRegistrationController do
  use KlaxonWeb, :controller

  alias Klaxon.Auth
  alias Klaxon.Auth.User
  alias KlaxonWeb.UserAuth

  def new(conn, _params) do
    changeset = Auth.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    {:ok, profile} = current_profile(conn)
    endpoint = endpoint(profile)

    case Auth.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Auth.deliver_user_confirmation_instructions(
            endpoint,
            user,
            &Routes.user_confirmation_url(endpoint, :edit, &1)
          )

        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
