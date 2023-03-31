defmodule Klaxon.Media.Impression do
  use Klaxon.Schema

  schema "impressions" do
    field :data, :binary
    field :height, :integer, default: 0
    field :size, :integer, default: 0
    field :usage, Ecto.Enum, values: [:raw, :avatar, :thumbnail, :gallery, :full], default: :raw
    field :width, :integer, default: 0

    belongs_to :media, Klaxon.Media.Media, type: EctoBase58

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(impression, attrs) do
    impression
    |> cast(attrs, [:media_id, :height, :width, :size, :use, :data])
    |> validate_required([:use, :data])
  end
end
