defmodule Klaxon.Contents.Helpers do
  import Ecto.Changeset

  @doc """
  Applies the content HTML to the changeset if the `:source` field has changed.

  ## Examples

      iex> changeset = %Ecto.Changeset{changes: %{source: "some source"}}
      iex> Klaxon.Contents.Helpers.apply_content_html(changeset)
      %Ecto.Changeset{changes: %{source: "some source", content_html: "<p>some source</p>"}}

  """
  @spec apply_content_html(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def apply_content_html(changeset) do
    if source = get_change(changeset, :source) do
      put_change_content_html(changeset, source)
    end || changeset
  end

  @doc """
  Forces a change to the `:content_html` field in the changeset based on the given source.

  ## Examples

      iex> changeset = %Ecto.Changeset{}
      iex> Klaxon.Contents.Helpers.put_change_content_html(changeset, "some source")
      %Ecto.Changeset{changes: %{content_html: "<p>some source</p>"}}

  """
  @spec put_change_content_html(Ecto.Changeset.t(), String.t()) :: Ecto.Changeset.t()
  def put_change_content_html(changeset, source) do
    force_change(
      changeset,
      :content_html,
      source
      |> Earmark.as_html!(compact_output: true)
    )
  end

  @doc """
  Sets the `:published_at` field to the current UTC datetime if the `:status` field is changed to `:published` and `:published_at` is not already set.

  ## Examples

      iex> changeset = %Ecto.Changeset{changes: %{status: :published}}
      iex> Klaxon.Contents.Helpers.apply_published_at(changeset)
      %Ecto.Changeset{changes: %{status: :published, published_at: ~U[2025-03-15 12:34:56Z]}}

  """
  @spec apply_published_at(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def apply_published_at(changeset) do
    published_at = get_field(changeset, :published_at)

    if get_change(changeset, :status) == :published && !published_at do
      put_change(changeset, :published_at, DateTime.utc_now())
    end || changeset
  end
end
