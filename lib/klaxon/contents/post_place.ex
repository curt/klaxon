defmodule Klaxon.Contents.PostPlace do
  @type t :: %__MODULE__{
          id: String.t(),
          post_id: String.t(),
          place_id: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  use Klaxon.Schema
  import Ecto.Changeset

  schema "post_places" do
    belongs_to :post, Klaxon.Contents.Post, type: EctoBase58
    belongs_to :place, Klaxon.Contents.Place, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(post_place, attrs) do
    post_place
    |> cast(attrs, [:post_id, :place_id])
    |> validate_required([:post_id, :place_id])
    |> unique_constraint([:post_id, :place_id])
  end
end
