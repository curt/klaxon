defmodule Klaxon.Blocks.Block do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  @timestamps_opts [type: :utc_datetime_usec]

  @primary_key {:id, EctoBase58, autogenerate: true}
  @foreign_key_type EctoBase58
  schema "blocks" do
    field :reason, :string
    field :subject, :string
    field :type, Ecto.Enum, values: [:domain, :subdomain, :profile, :object, :context]

    belongs_to :profile, Klaxon.Profiles.Profile, type: EctoBase58

    timestamps()
  end

  @doc false
  def changeset(block, attrs) do
    block
    |> cast(attrs, [:subject, :reason, :type])
    |> validate_required([:subject, :type])
  end

  def or_where_profile_type_subject(query, profile_id, type, subject) when is_list(subject) do
    query
    |> or_where([b], b.profile_id == ^profile_id and b.type == ^type and b.subject in ^subject)
  end

  def or_where_profile_type_subject(query, profile_id, type, subject) when is_binary(subject) do
    query
    |> or_where([b], b.profile_id == ^profile_id and b.type == ^type and b.subject == ^subject)
  end

  def or_where_profile_type_subject(query, _profile_id, _type, _subject) do
    query
  end
end
