defmodule Klaxon.Repo.Migrations.CreateIndexProfilesName do
  use Ecto.Migration

  def change do
    create index(:profiles, [:name])
  end
end
