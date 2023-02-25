defmodule Klaxon.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :profile_id, :binary_id, null: false
      add :uri, :text, null: false
      add :context_uri, :text, null: false
      add :in_reply_to_uri, :text
      add :slug, :text
      add :source, :text
      add :content_html, :text
      add :title, :text
      add :origin, :string, null: false
      add :status, :string, null: false
      add :visibility, :string, null: false
      add :published_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end
  end
end
