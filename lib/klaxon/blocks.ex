defmodule Klaxon.Blocks do
  @moduledoc """
  Interactions between `Klaxon.Blocks` schemas and repo.
  """
  require Logger
  alias Klaxon.Repo
  alias Klaxon.Blocks.Block
  import Ecto.Query

  def actor_blocked?(actor, profile_id) do
    %{host: domain} = URI.new!(actor)
    domain_path = String.split(domain, ".")
    subdomains = for parts <- 1..length(domain_path), do: Enum.join(Enum.slice(domain_path, -parts, parts), ".")

    Repo.exists?(from b in Block,
      where: b.profile_id == ^profile_id
      and (
        (b.type == :domain and b.subject == ^domain)
        or (b.type == :subdomain and b.subject in ^subdomains)
        or (b.type == :profile and b.subject == ^actor)
      )
    )
  end
end
