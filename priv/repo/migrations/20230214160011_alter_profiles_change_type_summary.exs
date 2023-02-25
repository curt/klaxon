defmodule Klaxon.Repo.Migrations.AlterProfilesChangeTypeSummary do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      modify :summary, :text, from: {:string, null: true}
    end
  end
end
