defmodule Klaxon.Repo.Migrations.AlterProfilesAddInbox do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :inbox, :text
    end
  end
end
