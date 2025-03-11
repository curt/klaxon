defmodule Klaxon.Repo.Migrations.AddProfileToTrace do
  use Ecto.Migration

  def change do
    alter table(:traces) do
      add :profile_id, references(:profiles, type: :binary_id), null: false
    end
  end
end
