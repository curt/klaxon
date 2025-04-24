defmodule Klaxon.Repo.Migrations.ChangeColumnsToTextInPlaces do
  use Ecto.Migration

  def change do
    alter table(:places) do
      modify :uri, :text, null: false
      modify :content_html, :text
      modify :source, :text
      modify :slug, :text
      modify :title, :text, null: false
    end
  end
end
