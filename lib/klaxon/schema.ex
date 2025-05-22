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
        struct |> Map.take(__schema__(:fields) ++ __schema__(:virtual_fields))
      end

      def to_map(other) do
        other
      end

      @spec apply_tag(Ecto.Changeset.t(), URI.t() | binary, atom, binary) ::
              Ecto.Changeset.t() | nil
      def apply_tag(changeset, endpoint, field, context) do
        host = convert_endpoint_to_host(endpoint)

        unless get_field(changeset, field) do
          put_change(
            changeset,
            field,
            TagUri.generate_random(host, context)
          )
        end || changeset
      end

      defp convert_endpoint_to_host(%URI{host: host} = _), do: host

      defp convert_endpoint_to_host(endpoint), do: URI.parse(endpoint).host || endpoint
    end
  end
end
