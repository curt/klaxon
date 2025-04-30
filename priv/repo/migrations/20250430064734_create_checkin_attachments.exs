defmodule Klaxon.Repo.Migrations.CreateCheckinAttachments do
  use Ecto.Migration

  def change do
    create table(:checkin_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :caption, :string

      add :checkin_id, references(:checkins, type: :binary_id, on_delete: :delete_all),
        null: false

      add :media_id, references(:media, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:checkin_attachments, [:checkin_id])
    create index(:checkin_attachments, [:media_id])
  end
end
