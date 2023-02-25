defmodule Klaxon.Repo.Migrations.CreateProfiles do
  use Ecto.Migration

  def change do
    create table(:profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uri, :string, null: false
      add :name, :string, null: false
      add :display_name, :string
      add :summary, :string
      add :public_key, :text
      add :private_key, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:profiles, [:uri])
  end
end
