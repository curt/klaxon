defmodule Klaxon.Repo.Migrations.CreatePlaces do
  use Ecto.Migration

  def change do
    create table(:places) do
      add :content_html, :string
      add :origin, :string, null: false, default: "remote"
      add :published_at, :utc_datetime_usec
      add :slug, :string
      add :source, :string
      add :status, :string, null: false, default: "draft"
      add :title, :string, null: false
      add :uri, :string, null: false
      add :visibility, :string, null: false, default: "public"
      add :lat, :float, null: false
      add :lon, :float, null: false
      add :ele, :float
      add :profile_id, references(:profiles, type: :binary_id)

      timestamps()
    end

    create unique_index(:places, [:uri])
    create index(:places, [:profile_id])
  end
end
