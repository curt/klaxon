defmodule Klaxon.Repo.Migrations.AlterAttachmentsChangeTypeCaption do
  use Ecto.Migration

  def change do
    alter table(:attachments) do
      modify :caption, :text, null: false, from: {:string, null: false}
    end
  end
end
