defmodule Klaxon.Activities.Inbox.Async do
  require Logger
  alias Klaxon.Blocks
  alias Klaxon.Contents
  alias Klaxon.Profiles
  alias Klaxon.Contents.Post
  alias Klaxon.Profiles.Profile

  @doc """
  Processes an inbound activity. The activity should have already been checked for well-formedness.
  """
  @spec process(map) :: :ok | :reject
  def process(%{} = args) do
    {activity, args} = Map.pop!(args, "activity")

    try do
      activity =
        activity
        |> maybe_normalize_id("actor")
        |> maybe_block_actor(args)
        |> dereference_actor()
        |> verify_signature(args)
        |> process(args)

      Logger.info("processed good inbound activity: #{inspect(activity)}")
      :ok
    rescue
      ex ->
        Logger.error("failed inbound activity: #{inspect(activity)}\n#{inspect(ex)}")
        Logger.error(Exception.format_stacktrace())
        {:cancel, inspect(ex)}
    catch
      :reject ->
        Logger.info("rejected inbound activity: #{inspect(activity)}")
        :ok
    end
  end

  def process(_args) do
    {:cancel}
  end

  def process(%{"type" => "Create", "object" => _object} = activity, args) do
    activity =
      activity
      |> maybe_normalize_id("object")
      |> dereference_object(args)
      |> maybe_block_object(args)
      |> verify_attributed_to_against_actor()
      |> check_acceptability("object")

    actor_profile =
      activity
      |> Map.fetch!("actor")

    object_post =
      activity
      |> Map.fetch!("object")
      |> Map.put(:profile, actor_profile)

    Logger.debug("attempting to insert or update post: #{inspect(object_post)}")
    Contents.insert_or_update_public_post(%Post{}, object_post)
  end

  def process(_activity, _args) do
    throw(:reject)
  end

  defp maybe_normalize_id(%{} = object, key) do
    case Map.fetch(object, key) do
      {:ok, attr} ->
        id = validate_publicly_dereferencable_uri(attr)

        if id != attr do
          object |> Map.put(key, id)
        else
          object
        end

      _ ->
        Logger.debug("unable to normalize id of #{key} from: #{inspect(object)}")
        throw(:reject)
    end
  end

  defp validate_publicly_dereferencable_uri(id) when is_binary(id) do
    case URI.new(id) do
      {:ok, uri} ->
        if uri.scheme in ["http", "https"] and uri.host do
          id
        else
          Logger.debug("scheme #{uri.scheme} not a publicly dereferencable URI: #{id}")
          throw(:reject)
        end

      _ ->
        Logger.debug("not a valid URI: #{id}")
        throw(:reject)
    end
  end

  defp validate_publicly_dereferencable_uri(%{"id" => id}) when is_binary(id) do
    validate_publicly_dereferencable_uri(id)
  end

  defp validate_publicly_dereferencable_uri(%{} = obj) do
    Logger.debug("unable to validate identifier: #{inspect(obj)}")
    throw(:reject)
  end

  # TODO: implement
  defp verify_signature(activity, _args) do
    activity
  end

  defp maybe_block_actor(
         %{"actor" => actor_uri} = activity,
         %{"profile" => %{"id" => profile_id}} = _args
       ) do
    if Blocks.actor_blocked?(actor_uri, profile_id) do
      Logger.debug("actor blocked #{actor_uri}")
      throw(:reject)
    end

    activity
  end

  defp maybe_block_object(
         %{"object" => object} = activity,
         %{"profile" => %{"id" => profile_id}} = _args
       ) do
    if Blocks.object_blocked?(object, profile_id) do
      Logger.debug("object blocked #{inspect(object)}")
      throw(:reject)
    end

    activity
  end

  defp verify_attributed_to_against_actor(
         %{"actor" => %{uri: actor_uri}, "object" => %{__attributed_to: attributed_to}} = activity
       ) do
    unless actor_uri == attributed_to do
      Logger.debug("failed verify attributed_to against actor #{activity}")
      throw(:reject)
    end

    activity
  end

  defp verify_attributed_to_against_actor(activity) do
    Logger.debug("unable to verify attributed_to against actor #{activity}")
    throw(:reject)
  end

  # TODO: This is a stub.
  # Implementing this depends on items not yet created.
  defp check_acceptability(activity, _attribute) do
    activity
  end

  defp dereference_actor(activity) do
    actor_uri = Map.fetch!(activity, "actor")

    profile =
      actor_uri
      |> Profiles.get_or_fetch_public_profile_by_uri()
      |> Profile.to_map()

    if !profile do
      Logger.debug("unable to dereference actor #{actor_uri}")
      throw(:reject)
    end

    profile =
      unless Map.has_key?(profile, :id) do
        # Because we may have fetched a public actor with a different
        # canonical `id` due to an HTTP redirect, attempt to re-get the profile
        # from the repository.
        canonical_uri = Map.get(profile, :uri)

        unless actor_uri == canonical_uri do
          re_get_profile = Profiles.get_public_profile_by_uri(canonical_uri)

          if re_get_profile && !Map.has_key?(profile, :id) do
            Map.put(profile, :id, Map.get(re_get_profile, :id))
          end
        end
      end || profile

    Logger.debug("dereferenced actor #{actor_uri} to #{inspect(profile)}")
    Map.put(activity, "actor", profile)
  end

  defp dereference_object(activity, %{"profile" => profile} = _args) do
    object_uri = Map.fetch!(activity, "object")

    post =
      object_uri
      |> Contents.get_or_fetch_public_post_by_uri(profile)
      |> Post.to_map()

    if !post do
      Logger.debug("unable to dereference object #{object_uri}")
      throw(:reject)
    end

    post =
      unless Map.has_key?(post, :id) do
        # Because we may have fetched a public object with a different
        # canonical `id` due to an HTTP redirect, attempt to re-get the post
        # from the repository.
        canonical_uri = Map.get(post, :uri)

        unless object_uri == canonical_uri do
          re_get_post = Contents.get_public_post_by_uri(canonical_uri)

          if re_get_post && !Map.has_key?(post, :id) do
            Map.put(post, :id, Map.get(re_get_post, :id))
          end
        end
      end || post

    Logger.debug("dereferenced object #{object_uri} to #{inspect(post)}")
    Map.put(activity, "object", post)
  end
end
