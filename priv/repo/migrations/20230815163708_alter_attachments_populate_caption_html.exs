defmodule Klaxon.Repo.Migrations.AlterAttachmentsPopulateCaptionHtml do
  require Logger
  use Ecto.Migration

  def up do
    # This migration is not needed anymore.
    # It was used as a one-off to populate the caption_html field in the attachments table,
    # which has since had its name changed.
  end

  def down do
  end
end
