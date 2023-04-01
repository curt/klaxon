# TODO: This is a mess and can be greatly simplified.
defmodule Klaxon.Webfinger do
  import Ecto.Query, warn: false
  alias Klaxon.Profiles.Profile

  @spec get_webfinger(%Profile{}, String.t()) ::
          {:error, :bad_request | :not_found} | {:ok, {%Profile{}, String.t()}}
  def get_webfinger(%Profile{} = profile, resource) do
    with {:ok, acct} <- parse_resource(resource),
         {:ok, name, host} <- parse_acct(acct, profile.uri),
         {:ok, profile} <- match_profile(profile, name, host) do
      {:ok, {profile, canonical_resource(name, host)}}
    end
  end

  defp parse_resource(resource) do
    case Regex.split(~r{:}, resource, parts: 2) do
      ["acct", acct] -> {:ok, acct}
      _ -> {:error, :bad_request}
    end
  end

  defp parse_acct(acct, endpoint) do
    case Regex.split(~r{@}, acct) do
      [name, host] -> {:ok, name, host}
      [name] -> {:ok, name, URI.new!(endpoint).host}
      _ -> {:error, :bad_request}
    end
  end

  defp match_profile(%Profile{} = profile, name, host) do
    if profile.name == name and URI.new!(profile.uri).host == host do
      {:ok, profile}
    else
      {:error, :not_found}
    end
  end

  defp canonical_resource(name, host), do: "acct:#{name}@#{host}"
end
