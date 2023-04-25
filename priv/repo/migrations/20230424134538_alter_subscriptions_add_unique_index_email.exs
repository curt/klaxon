defmodule Klaxon.Repo.Migrations.AlterSubscriptionsAddUniqueIndexEmail do
  use Ecto.Migration

  def change do
    create unique_index(:subscriptions, [:email])
  end
end
