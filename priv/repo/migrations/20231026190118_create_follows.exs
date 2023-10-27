defmodule Klaxon.Repo.Migrations.CreateFollows do
  use Ecto.Migration

  def change do
    create table(:follows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uri, :string, null: false
      add :follower_uri, :string, null: false
      add :followee_uri, :string, null: false
      add :status, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:follows, [:uri])
    create unique_index(:follows, [:follower_uri, :followee_uri])
  end
end
