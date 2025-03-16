defmodule Klaxon.Repo.Migrations.CreatePlaceTags do
  use Ecto.Migration

  def change do
    create table(:place_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :place_id, references(:places, on_delete: :nothing, type: :binary_id), null: false
      add :label_id, references(:labels, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:place_tags, [:place_id])
    create index(:place_tags, [:label_id])
  end
end
