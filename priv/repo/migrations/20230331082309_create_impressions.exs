defmodule Klaxon.Repo.Migrations.CreateImpression do
  use Ecto.Migration

  def change do
    create table(:impressions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :height, :integer, null: false
      add :width, :integer, null: false
      add :size, :integer, null: false
      add :usage, :string, null: false
      add :data, :binary
      add :media_id, references(:media, on_delete: :nothing, type: :binary_id)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create index(:impressions, [:media_id])
    create unique_index(:impressions, [:media_id, :usage])
  end
end
