defmodule Klaxon.Repo.Migrations.AlterAttachmentsAddCaptionHtml do
  use Ecto.Migration

  def change do
    alter table(:attachments) do
      add :caption_html, :text
    end
  end
end
