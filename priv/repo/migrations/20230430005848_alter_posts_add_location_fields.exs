defmodule Klaxon.Repo.Migrations.AlterPostsAddLocationFields do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :lat, :float
      add :lon, :float
      add :ele, :float
      add :location, :text
    end
  end
end
