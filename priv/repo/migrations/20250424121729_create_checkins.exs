defmodule Klaxon.Repo.Migrations.CreateCheckins do
  use Ecto.Migration

  def change do
    create table(:checkins, primary_key: false) do
      add :checked_in_at, :utc_datetime_usec, null: false
      add :id, :binary_id, primary_key: true
      add :content_html, :text
      add :origin, :string, null: false
      add :published_at, :utc_datetime_usec
      add :source, :text
      add :status, :string, null: false
      add :uri, :text, null: false
      add :visibility, :string, null: false
      add :profile_id, references(:profiles, on_delete: :nothing, type: :binary_id), null: false
      add :place_id, references(:places, on_delete: :nothing, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:checkins, [:profile_id])
    create index(:checkins, [:place_id])
  end
end
