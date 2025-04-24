defmodule Klaxon.Checkins.Checkin do
  use Klaxon.Schema
  import Klaxon.Contents.Helpers
  import Ecto.Changeset

  schema "checkins" do
    field :status, Ecto.Enum, values: [:draft, :published, :deleted], default: :draft
    field :origin, Ecto.Enum, values: [:local, :remote], default: :remote
    field :source, :string
    field :uri, :string
    field :content_html, :string
    field :visibility, Ecto.Enum, values: [:private, :unlisted, :public], default: :public
    field :published_at, :utc_datetime_usec

    belongs_to(:profile, Klaxon.Profiles.Profile, type: EctoBase58)
    belongs_to(:place, Klaxon.Contents.Place, type: EctoBase58)

    timestamps()
  end

  @doc false
  def changeset(checkin, attrs) do
    checkin
    |> cast(attrs, [
      :source,
      :content_html,
      :uri,
      :origin,
      :status,
      :visibility,
      :published_at,
      :profile_id,
      :place_id
    ])
    |> validate_required([:uri, :origin, :status, :visibility])
    |> unique_constraint(:uri)
    |> apply_published_at()
  end
end
