defmodule Klaxon.Activities.Inbox.Async do
  require Logger
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
        |> maybe_reference_id("actor")
        |> check_against_actor_blocklist("actor")
        |> dereference_actor()
        |> verify_signature(args)
        |> process(args)

      Logger.info("good inbound activity: #{inspect(activity)}")
      :ok
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
      |> maybe_reference_id("object")
      |> check_against_object_blocklist("object")
      |> dereference_object("object")
      |> check_object_attribute_against_actor_uri("object", "attributedTo")
      |> check_acceptability("object")

    activity
  end

  def process(_activity, _args) do
    throw(:reject)
  end

  defp maybe_reference_id(%{} = object, key) do
    case Map.fetch(object, key) do
      {:ok, attr} ->
        id = validate_publicly_dereferencable_uri(attr)

        if id != attr do
          object |> Map.put(key, id)
        else
          object
        end

      _ ->
        Logger.debug("unable to reference #{inspect(key)} from: #{inspect(object)}")
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

  # TODO: implement
  defp check_against_actor_blocklist(%{} = activity, attribute) do
    _actor = Map.fetch!(activity, attribute)
    activity
  end

  # TODO: implement
  defp check_against_object_blocklist(%{} = activity, attribute) do
    _object = Map.fetch!(activity, attribute)
    activity
  end

  # TODO: rewrite this against dereferenced types
  defp check_object_attribute_against_actor_uri(
         %{"actor" => %Profile{uri: actor_uri}} = activity,
         attribute,
         object_attribute
       ) do
    check_uri =
      Map.fetch!(activity, attribute)
      |> maybe_reference_id(object_attribute)

    if check_uri == actor_uri do
      activity
    else
      Logger.debug("#{object_attribute} URI does not equal actor URI #{actor_uri}")
      throw(:reject)
    end
  end

  # TODO: implement
  defp check_acceptability(activity, _attribute) do
    activity
  end

  defp dereference_actor(activity) do
    activity
  end

  defp dereference_object(activity, attribute) do
    _object = Map.fetch!(activity, attribute)
    activity
  end
end
