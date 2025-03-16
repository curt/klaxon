defmodule Klaxon.Repo.Migrations.RenamePostTagsConstraintsIndexes do
  use Ecto.Migration

  def up do
    # Rename indexes
    execute "ALTER INDEX tags_label_id_index RENAME TO post_tags_label_id_index"
    execute "ALTER INDEX tags_post_id_index RENAME TO post_tags_post_id_index"

    # Rename constraints
    execute "ALTER TABLE post_tags RENAME CONSTRAINT tags_label_id_fkey TO post_tags_label_id_fkey"
    execute "ALTER TABLE post_tags RENAME CONSTRAINT tags_post_id_fkey TO post_tags_post_id_fkey"
    execute "ALTER TABLE post_tags RENAME CONSTRAINT tags_pkey TO post_tags_pkey"
  end

  def down do
    # Rename indexes
    execute "ALTER INDEX post_tags_label_id_index RENAME TO tags_label_id_index"
    execute "ALTER INDEX post_tags_post_id_index RENAME TO tags_post_id_index"

    # Rename constraints
    execute "ALTER TABLE post_tags RENAME CONSTRAINT post_tags_label_id_fkey TO tags_label_id_fkey"
    execute "ALTER TABLE post_tags RENAME CONSTRAINT post_tags_post_id_fkey TO tags_post_id_fkey"
    execute "ALTER TABLE post_tags RENAME CONSTRAINT post_tags_pkey TO tags_pkey"
  end
end
