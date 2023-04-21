defmodule Klaxon.Contents.Attachment do
  use Klaxon.Schema

  schema "attachments" do
    field :caption, :string

    belongs_to :post, Klaxon.Contents.Post, type: EctoBase58
    belongs_to :media, Klaxon.Media.Media, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(attachment, attrs \\ %{}) do
    attachment
    |> cast(attrs, [:caption])
    |> validate_required([:caption])
  end
end
