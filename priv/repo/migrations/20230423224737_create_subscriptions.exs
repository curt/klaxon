defmodule Klaxon.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :key, :string, null: false
      add :confirmed_at, :utc_datetime_usec
      add :last_published_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end
  end
end
