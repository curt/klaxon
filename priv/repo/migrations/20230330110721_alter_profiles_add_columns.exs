defmodule Klaxon.Repo.Migrations.AlterProfilesAddColumns do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :public_key_id, :text
      add :url, :text
      add :icon, :text
      add :icon_media_type, :string
      add :image, :text
      add :image_media_type, :string
    end
  end
end
