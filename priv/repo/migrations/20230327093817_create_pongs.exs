defmodule Klaxon.Repo.Migrations.CreatePongs do
  use Ecto.Migration

  def change do
    create table(:pongs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uri, :string
      add :direction, :string
      add :actor_uri, :string
      add :to_uri, :string
      add :object_uri, :string

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create index(:pongs, [:to_uri])
    create index(:pongs, [:actor_uri])
    create index(:pongs, [:object_uri])
    create unique_index(:pongs, [:uri, :direction])
  end
end
