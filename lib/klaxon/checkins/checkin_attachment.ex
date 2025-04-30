defmodule Klaxon.Checkins.CheckinAttachment do
  use Klaxon.Schema

  schema "checkin_attachments" do
    field :caption, :string

    belongs_to :checkin, Klaxon.Checkins.Checkin, type: EctoBase58
    belongs_to :media, Klaxon.Media.Media, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(checkin_attachment, attrs \\ %{}) do
    checkin_attachment
    |> cast(attrs, [:caption])
  end
end
