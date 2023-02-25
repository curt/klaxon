defmodule Klaxon.Repo.Migrations.CreatePrincipals do
  use Ecto.Migration

  def change do
    create table(:principals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :profile_id, references(:profiles, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:principals, [:user_id])
    create index(:principals, [:profile_id])
  end
end
