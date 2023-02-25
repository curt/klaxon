defmodule KlaxonWeb.Titles do
  alias Klaxon.Profiles.Profile
  alias Klaxon.Contents.Post

  def title(%Post{title: nil} = post) do
    id = String.slice(post.id, -7, 7)

    status =
      case post.status do
        :draft -> "draft"
        _ -> "post"
      end

    Enum.join(["Untitled", status, id], " ")
  end

  def title(%Post{} = post) do
    post.title
  end

  def title(%Profile{} = profile) do
    profile.display_name || profile.name
  end

  def title(items) when is_list(items) do
    # FIXME
    "Posts"
  end

  def title({:error, title}) do
    title
  end

  def title(_) do
    "Untitled"
  end
end
