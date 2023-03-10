defmodule Klaxon.Activities.Inbox.Async do
  require Logger
  alias Klaxon.Profiles
  alias Klaxon.Profiles.Profile
  alias Klaxon.Contents
  alias Klaxon.Blocks

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

      Logger.info("good inbound activity: #{inspect(activity)}")
      :ok
    rescue
      ex ->
        Logger.error("failed inbound activity: #{inspect(activity)}\n#{inspect(ex)}")
        {:cancel, inspect(ex)}
    catch
      :reject ->
        Logger.info("rejected inbound activity: #{inspect(activity)}")
        :ok

      _ ->
        msg = "invalid response for inbound activity: #{inspect(activity)}"
        Logger.error(msg)
        {:cancel, msg}
    end
  end

  def process(_args) do
    {:cancel}
  end

  def process(%{"type" => "Create", "object" => _object} = activity, _args) do
    activity =
      activity
      |> maybe_normalize_id("object")
      |> maybe_block_object()
      |> dereference_object()
      |> check_object_attribute_against_actor_uri("object", "attributedTo")
      |> check_acceptability("object")

    activity
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
          Logger.debug("not a publicly dereferencable URI: #{id}")
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

  # Note: Actor should be normalized to a URI string.
  defp maybe_block_actor(
         %{} = activity,
         %{"profile_id" => profile_id} = _args
       ) do
    actor_uri = Map.fetch!(activity, "actor")

    if Blocks.actor_blocked?(actor_uri, profile_id) do
      Logger.debug("actor blocked #{actor_uri}")
      throw(:reject)
    end

    activity
  end

  # TODO: implement
  defp maybe_block_object(%{} = activity) do
    _object = Map.fetch!(activity, "object")
    activity
  end

  # TODO: rewrite this against dereferenced types
  defp check_object_attribute_against_actor_uri(
         %{"actor" => %Profile{uri: _actor_uri}} = activity,
         attribute,
         _object_attribute
       ) do
    check_uri = Map.get(activity, attribute)

    if !check_uri do
      Logger.debug("attribute #{attribute} not found on activity #{inspect(activity)}")
      throw(:reject)
    end

    # FIXME!
    # check_uri =
    #   check_uri
    #   |> maybe_normalize_id(object_attribute)

    # if check_uri == actor_uri do
    #   activity
    # else
    #   Logger.debug("#{object_attribute} URI does not equal actor URI #{actor_uri}")
    #   throw(:reject)
    # end
    activity
  end

  # TODO: implement
  defp check_acceptability(activity, _attribute) do
    activity
  end

  defp dereference_actor(activity) do
    actor_uri = Map.fetch!(activity, "actor")
    profile = Profiles.get_or_fetch_public_profile_by_uri(actor_uri)

    if !profile do
      Logger.debug("unable to dereference actor #{actor_uri}")
      throw(:reject)
    else
      Logger.debug("dereferenced actor #{actor_uri} to #{inspect(profile)}")
    end

    Map.put(activity, "actor", profile)
  end

  defp dereference_object(activity) do
    object_uri = Map.fetch!(activity, "object")
    post = Contents.get_or_fetch_public_post_by_uri(object_uri)

    if !post do
      Logger.debug("unable to dereference object #{object_uri}")
      throw(:reject)
    else
      Logger.debug("dereferenced object #{object_uri} to #{inspect(post)}")
    end

    Map.put(activity, "object", post)
  end
end
