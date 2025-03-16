defmodule Klaxon.Contents.PostAttachment do
  use Klaxon.Schema

  schema "post_attachments" do
    field :caption, :string

    belongs_to :post, Klaxon.Contents.Post, type: EctoBase58
    belongs_to :media, Klaxon.Media.Media, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(post_attachment, attrs \\ %{}) do
    post_attachment
    |> cast(attrs, [:caption])
    |> validate_required([:caption])
  end
end
