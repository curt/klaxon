defmodule Klaxon.Repo.Migrations.CreateCheckins do
  use Ecto.Migration

  def change do
    create table(:checkins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :text
      add :content_html, :text
      add :uri, :text
      add :origin, :string
      add :status, :string
      add :visibility, :string
      add :published_at, :utc_datetime_usec
      add :profile_id, references(:profiles, on_delete: :nothing, type: :binary_id)
      add :place_id, references(:places, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:checkins, [:profile_id])
    create index(:checkins, [:place_id])
  end
end
