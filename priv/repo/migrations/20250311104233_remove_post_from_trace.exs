defmodule Klaxon.Repo.Migrations.RemovePostFromTrace do
  use Ecto.Migration

  def change do
    alter table(:traces) do
      remove :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
    end
  end
end
