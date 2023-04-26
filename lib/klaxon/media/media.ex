defmodule Klaxon.Media.Media do
  use Klaxon.Schema

  schema "media" do
    field :description, :string
    field :mime_type, :string
    field :origin, Ecto.Enum, values: [:local, :remote], default: :remote
    field :scope, Ecto.Enum, values: [:profile, :post], default: :profile
    field :uri, :string

    has_many :impressions, Klaxon.Media.Impression

    timestamps()
  end

  @doc false
  def changeset(media, attrs) do
    media
    |> cast(attrs, [:id, :origin, :scope, :mime_type, :uri, :description])
    |> validate_required([:origin, :scope, :mime_type, :uri])
  end
end
