defmodule Klaxon.Repo.Migrations.AlterAttachmentsPopulateCaptionHtml do
  require Logger
  use Ecto.Migration

  def up do
    for attachment <- Klaxon.Repo.all(Klaxon.Contents.Attachment) do
      if attachment.caption do
        Klaxon.Contents.Attachment.changeset(attachment, %{
          caption_html: String.trim(Earmark.as_html!(attachment.caption, inner_html: true))
        })
        |> Klaxon.Repo.update()
      end
    end
  end

  def down do
  end
end
