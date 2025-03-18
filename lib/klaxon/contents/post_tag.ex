defmodule Klaxon.Contents.PostTag do
  @type t :: %__MODULE__{
          id: binary(),
          post_id: binary(),
          label_id: binary(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  use Ecto.Schema
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  @foreign_key_type EctoBase58
  schema "post_tags" do
    belongs_to :post, Klaxon.Contents.Post, type: EctoBase58
    belongs_to :label, Klaxon.Contents.Label, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(post_tag, attrs) do
    post_tag
    |> cast(attrs, [])
    |> validate_required([])
  end
end
