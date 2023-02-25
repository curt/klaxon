defmodule Klaxon.Repo.Migrations.CreateLabels do
  use Ecto.Migration

  def change do
    create table(:labels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :citext, null: false
      add :normalized, :citext, null: false
      add :slug, :citext, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:labels, [:slug])
    create unique_index(:labels, [:normalized])
  end
end
