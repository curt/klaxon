defmodule Klaxon.Blocks do
  @moduledoc """
  Interactions between `Klaxon.Blocks` schemas and repo.
  """
  require Logger
  alias Klaxon.Repo
  alias Klaxon.Blocks.Block

  @spec actor_blocked?(String.t(), String.t()) :: boolean
  def actor_blocked?(actor_uri, profile_id) do
    %{host: domain} = URI.new!(actor_uri)
    domain_path = String.split(domain, ".")

    subdomains =
      for parts <- 1..length(domain_path),
          do: Enum.join(Enum.slice(domain_path, -parts, parts), ".")

    Block
    |> Block.or_where_profile_type_subject(profile_id, :domain, domain)
    |> Block.or_where_profile_type_subject(profile_id, :subdomain, subdomains)
    |> Block.or_where_profile_type_subject(profile_id, :profile, actor_uri)
    |> Repo.exists?()
  end

  @spec object_blocked?(map, String.t()) :: boolean
  def object_blocked?(%{} = object, profile_id) do
    object_uri = Map.get(object, :uri)
    context_uri = Map.get(object, :context_uri)
    in_reply_to_uri = Map.get(object, :in_reply_to_uri)

    Block
    |> Block.or_where_profile_type_subject(profile_id, :object, object_uri)
    |> Block.or_where_profile_type_subject(profile_id, :object, in_reply_to_uri)
    |> Block.or_where_profile_type_subject(profile_id, :context, context_uri)
    |> Repo.exists?()
  end
end
