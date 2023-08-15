defmodule Klaxon.Contents.Attachment do
  use Klaxon.Schema

  schema "attachments" do
    field :caption, :string
    field :caption_html, :string

    belongs_to :post, Klaxon.Contents.Post, type: EctoBase58
    belongs_to :media, Klaxon.Media.Media, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(attachment, attrs \\ %{}) do
    attachment
    |> cast(attrs, [:caption, :caption_html])
    |> validate_required([:caption])
  end

  def apply_caption_html(changeset) do
    if caption = get_change(changeset, :caption) do
      put_change(changeset, :caption_html, Earmark.as_html!(caption))
    end || changeset
  end
end
