defmodule Klaxon.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :subject, :text, null: false
      add :reason, :text
      add :type, :string, null: false
      add :profile_id, references(:profiles, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:blocks, [:profile_id])
    create unique_index(:blocks, [:subject, :type, :profile_id])
  end
end
