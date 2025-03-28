defmodule Klaxon.Repo.Migrations.RenameCreatedAt do
  use Ecto.Migration

  def change do
    rename table(:trackpoints), :created_at, to: :time
    rename table(:waypoints), :created_at, to: :time
  end
end
