defmodule Klaxon.Repo.Migrations.CreateTraceTables do
  use Ecto.Migration

  def change do
    create table(:traces, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :text

      timestamps(type: :utc_datetime_usec)
    end

    create table(:tracks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trace_id, references(:traces, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :text

      timestamps(type: :utc_datetime_usec)
    end

    create table(:segments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :track_id, references(:tracks, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create table(:trackpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :segment_id, references(:segments, type: :binary_id, on_delete: :delete_all), null: false
      add :lat, :float
      add :lon, :float
      add :ele, :float
      add :name, :text
      add :created_at, :utc_datetime_usec
    end

    create table(:waypoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trace_id, references(:traces, type: :binary_id, on_delete: :delete_all), null: false
      add :lat, :float
      add :lon, :float
      add :ele, :float
      add :name, :text
      add :created_at, :utc_datetime_usec
    end

    create index(:traces, [:post_id])

    create index(:tracks, [:trace_id])

    create index(:segments, [:track_id])

    create index(:trackpoints, [:segment_id])

    create index(:trackpoints, [:segment_id, :created_at])

    create index(:waypoints, [:trace_id])

    create index(:waypoints, [:trace_id, :created_at])
  end
end
