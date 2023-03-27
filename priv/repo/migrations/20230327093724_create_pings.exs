defmodule Klaxon.Repo.Migrations.CreatePings do
  use Ecto.Migration

  def change do
    create table(:pings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uri, :string
      add :direction, :string
      add :actor_uri, :string
      add :to_uri, :string

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create index(:pings, [:to_uri])
    create index(:pings, [:actor_uri])
    create unique_index(:pings, [:uri, :direction])
  end
end
