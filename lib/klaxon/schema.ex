defmodule Klaxon.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Query
      import Ecto.Changeset
      @timestamps_opts [type: :utc_datetime_usec]
      @primary_key {:id, EctoBase58, autogenerate: true}
      @foreign_key_type EctoBase58

      @spec to_map(struct | map | nil) :: map | nil
      def to_map(struct) when is_struct(struct) do
        struct
        |> Map.from_struct()
        |> Map.delete(:__meta__)
        |> Map.delete(:__struct__)
      end

      def to_map(other) do
        other
      end
    end
  end
end
