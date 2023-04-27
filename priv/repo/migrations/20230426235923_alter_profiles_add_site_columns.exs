defmodule Klaxon.Repo.Migrations.AlterProfilesAddSiteColumns do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :site_title, :text
      add :site_tag, :text
      add :site_text, :text
    end
  end
end
