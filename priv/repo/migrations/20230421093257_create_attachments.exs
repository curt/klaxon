defmodule Klaxon.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :caption, :string
      add :post_id, references(:posts, on_delete: :nothing, type: :binary_id)
      add :media_id, references(:media, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:attachments, [:post_id])
    create index(:attachments, [:media_id])
  end
end
