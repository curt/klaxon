defmodule Klaxon.Webfinger do
  import Ecto.Query, warn: false
  alias Klaxon.Profiles
  alias Klaxon.Profiles.Profile

  def get_webfinger!(resource) do
    case parse_resource(resource) do
      {:ok, %{type: "acct", username: name, hostname: host}}
        -> get_webfinger_profile!(name, host)
      {:ok, %{type: "acct", username: name}}
        -> get_webfinger_profile!(name)
      :error
        -> :error
    end
  rescue
    _ -> :error
  end

  def parse_resource(res) do
    parts = Regex.split(~r{:}, res, parts: 2)

    case parts do
      ["acct", acct] -> parse_account(acct)
      _ -> :error
    end
  end

  def parse_account(acct) do
    parts = Regex.split(~r{@}, acct)

    case parts do
      [user, host] -> {:ok, %{type: "acct", username: user, hostname: host}}
      [user] -> {:ok, %{type: "acct", username: user}}
      _ -> :error
    end
  end

  def get_webfinger_profile!(name) do
    case get_profile_and_host(name) do
      {%Profile{} = profile, profile_uri_host} ->
        {profile, canonical_resource(name, profile_uri_host)}
      _ -> nil
    end
  end

  def get_webfinger_profile!(name, host) do
    case get_profile_and_host(name) do
      {%Profile{} = profile, profile_uri_host} when host == profile_uri_host ->
        {profile, canonical_resource(name, profile_uri_host)}
      _ -> nil
    end
  end

  def get_profile_and_host(name) do
    profile = Profiles.get_local_profile!(name)
    case URI.new(profile.uri) do
      {:ok, %URI{} = uri} -> {profile, uri.host}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  def canonical_resource(name, host) do
    "acct:#{name}@#{host}"
  end
end
