defmodule Klaxon.Repo.Migrations.AlterSubscriptionsAddSchedule do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add :schedule, :string, null: false
    end
  end
end
