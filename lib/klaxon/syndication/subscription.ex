defmodule Klaxon.Syndication.Subscription do
  use Klaxon.Schema
  import Ecto.Changeset

  schema "subscriptions" do
    field :confirmed_at, :utc_datetime_usec
    field :email, :string
    field :key, :string
    field :schedule, Ecto.Enum, values: [:hourly, :daily, :weekly, :none], default: :none
    field :last_published_at, :utc_datetime_usec

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:email, :key, :confirmed_at, :schedule, :last_published_at])
    |> validate_required([:email, :schedule])
    |> unique_constraint(:email)
    |> apply_key()
  end

  def confirm_changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:confirmed_at])
  end

  def update_changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:schedule])
  end

  def apply_key(changeset) do
    unless get_field(changeset, :key) do
      random = Base58Check.Base58.encode(:crypto.strong_rand_bytes(32))
      put_change(
        changeset,
        :key,
        random
      )
    end || changeset
  end
end
