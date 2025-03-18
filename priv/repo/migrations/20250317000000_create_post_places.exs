defmodule Klaxon.Repo.Migrations.CreatePostPlaces do
  use Ecto.Migration

  def change do
    create table(:post_places, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :place_id, references(:places, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:post_places, [:post_id, :place_id])
  end
end
