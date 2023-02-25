defmodule Klaxon.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:posts, on_delete: :nothing, type: :binary_id), null: false
      add :label_id, references(:labels, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:tags, [:post_id])
    create index(:tags, [:label_id])
  end
end
