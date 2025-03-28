defmodule Klaxon.Repo.Migrations.AddTracesStatusVisibility do
  use Ecto.Migration

  def change do
    alter table(:traces) do
      add :status, :string, null: false, default: "raw"
      add :visibility, :string, null: false, default: "private"
    end
  end
end
