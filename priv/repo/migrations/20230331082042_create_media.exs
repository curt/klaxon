defmodule Klaxon.Repo.Migrations.CreateMedia do
  use Ecto.Migration

  def change do
    create table(:media, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :origin, :string, null: false
      add :scope, :string, null: false
      add :mime_type, :string, null: false
      add :uri, :text, null: false
      add :description, :text

      timestamps(type: :utc_datetime_usec)
    end
  end
end
