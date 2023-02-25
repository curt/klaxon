defmodule Klaxon.Repo.Migrations.AlterProfilesChangeTypeUri do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      modify :uri, :text, null: false, from: {:string, null: false}
    end
  end
end
