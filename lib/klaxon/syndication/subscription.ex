defmodule Klaxon.Syndication.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "subscriptions" do
    field :confirmed_at, :utc_datetime_usec
    field :email, :string
    field :key, :string
    field :last_published_at, :utc_datetime_usec

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:email, :key, :confirmed_at, :last_published_at])
    |> validate_required([:email, :key, :confirmed_at, :last_published_at])
  end
end
