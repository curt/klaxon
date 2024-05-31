defmodule KlaxonWeb.SubscriptionController do
  use KlaxonWeb, :controller
  alias Klaxon.Syndication
  alias Klaxon.Syndication.Subscription

  action_fallback KlaxonWeb.FallbackController

  def new(conn, _params) do
    changeset = Subscription.changeset(%Subscription{}, %{})
    render(conn, changeset: changeset)
  end

  def create(conn, %{"subscription" => subscription_params}) do
    with {:ok, _subscription} <-
           Syndication.insert_subscriber(
             subscription_params,
             sender(conn),
             &Routes.subscription_url(conn, :confirm, &1, &2)
           ) do
      conn
      |> put_flash(
        :info,
        "Tentative subscription created successfully. " <>
          "Please check e-mail inbox for confirmation link."
      )
      |> redirect(to: Routes.profile_path(conn, :index))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def confirm?(conn, %{"id" => id, "key" => key}) do
    with {:ok, subscription} <- Syndication.get_any_subscriber(id, key) do
      render(conn, :confirm?, subscription: subscription)
    end
  end

  def confirm(conn, %{"id" => id, "key" => key}) do
    with {:ok, _subscription} <- Syndication.confirm_subscriber(id, key) do
      conn
      |> put_flash(:info, "Subscription confirmed successfully.")
      |> redirect(to: Routes.subscription_path(conn, :edit, id, key))
    end
  end

  def edit(conn, %{"id" => id, "key" => key}) do
    with {:ok, subscription} <- Syndication.get_subscriber(id, key) do
      changeset = Subscription.changeset(subscription, %{})
      render(conn, changeset: changeset, id: id, key: key)
    end
  end

  def update(conn, %{"id" => id, "key" => key, "subscription" => subscription_params}) do
    with {:ok, _subscription} <- Syndication.update_subscriber(id, key, subscription_params) do
      conn
      |> put_flash(:info, "Subscription updated successfully.")
      |> redirect(to: Routes.profile_path(conn, :index))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, changeset: changeset, id: id, key: key)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete?(conn, %{"id" => id, "key" => key}) do
    with {:ok, subscription} <- Syndication.get_any_subscriber(id, key) do
      render(conn, :delete?, subscription: subscription)
    end
  end

  def delete(conn, %{"id" => id, "key" => key}) do
    with {:ok, _subscription} <- Syndication.delete_subscriber(id, key) do
      conn
      |> put_flash(:info, "Subscription deleted successfully.")
      |> redirect(to: Routes.profile_path(conn, :index))
    end
  end

  def unsubscribe(conn, %{"id" => id, "key" => key}) do
    case Syndication.delete_subscriber(id, key) do
      {:ok, _subscription} -> :noop
      {:error, :not_found} -> :noop
    end

    conn |> text(nil)
  end
end
