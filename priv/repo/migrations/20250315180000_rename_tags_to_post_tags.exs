defmodule Klaxon.Repo.Migrations.RenameTagsToPostTags do
  use Ecto.Migration

  def change do
    rename table(:tags), to: table(:post_tags)
  end
end
