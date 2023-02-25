defmodule KlaxonWeb.PostsView do
  use KlaxonWeb, :view
  import KlaxonWeb.Titles

  def status_action(post) do
    case post.status do
      :draft -> "Drafted"
      :published -> "Posted"
      _ -> "Appeared"
    end
  end

  def status_date(post) do
    case post.status do
      :published -> post.published_at || post.inserted_at
      _ -> post.inserted_at
    end
  end
end
