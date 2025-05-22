defmodule Klaxon.Repo.Migrations.CreateLikes do
  use Ecto.Migration

  def change do
    create table(:likes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uri, :text, null: false
      add :actor_uri, :text, null: false
      add :object_uri, :text, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:likes, [:uri])
    create unique_index(:likes, [:actor_uri, :object_uri])
  end
end
