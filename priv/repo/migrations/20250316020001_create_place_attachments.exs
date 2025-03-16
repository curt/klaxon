defmodule Klaxon.Repo.Migrations.CreatePlaceAttachments do
  use Ecto.Migration

  def change do
    create table(:place_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :caption, :string
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all)
      add :media_id, references(:media, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:place_attachments, [:place_id])
    create index(:place_attachments, [:media_id])
  end
end
