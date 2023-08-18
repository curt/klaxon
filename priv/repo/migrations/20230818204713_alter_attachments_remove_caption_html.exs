defmodule Klaxon.Repo.Migrations.AlterAttachmentsRemoveCaptionHtml do
  use Ecto.Migration

  def change do
    alter table(:attachments) do
      remove :caption_html, :text
    end
  end
end
