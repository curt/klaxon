defmodule Klaxon.Repo.Migrations.AlterProfilesAddOwnerId do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :owner_id, :binary_id
    end

    # From this point on, the principals table is vestigial.
    execute("update profiles set owner_id = principals.user_id from principals where principals.profile_id = profiles.id")
  end
end
