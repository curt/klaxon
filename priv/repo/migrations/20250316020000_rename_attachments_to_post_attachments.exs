defmodule Klaxon.Repo.Migrations.RenameAttachmentsToPostAttachments do
  use Ecto.Migration

  def up do
    rename table(:attachments), to: table(:post_attachments)

    # Rename indexes
    execute "ALTER INDEX attachments_post_id_index RENAME TO post_attachments_post_id_index"
    execute "ALTER INDEX attachments_media_id_index RENAME TO post_attachments_media_id_index"

    # Rename constraints
    execute "ALTER TABLE post_attachments RENAME CONSTRAINT attachments_post_id_fkey TO post_attachments_post_id_fkey"

    execute "ALTER TABLE post_attachments RENAME CONSTRAINT attachments_media_id_fkey TO post_attachments_media_id_fkey"

    execute "ALTER TABLE post_attachments RENAME CONSTRAINT attachments_pkey TO post_attachments_pkey"
  end

  def down do
    rename table(:post_attachments), to: table(:attachments)

    # Rename indexes
    execute "ALTER INDEX post_attachments_post_id_index RENAME TO attachments_post_id_index"
    execute "ALTER INDEX post_attachments_media_id_index RENAME TO attachments_media_id_index"

    # Rename constraints
    execute "ALTER TABLE attachments RENAME CONSTRAINT post_attachments_post_id_fkey TO attachments_post_id_fkey"

    execute "ALTER TABLE attachments RENAME CONSTRAINT post_attachments_media_id_fkey TO attachments_media_id_fkey"

    execute "ALTER TABLE attachments RENAME CONSTRAINT post_attachments_pkey TO attachments_pkey"
  end
end
