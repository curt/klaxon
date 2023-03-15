defmodule Klaxon.Activities.Inbox.Async do
  require Logger
  alias Klaxon.Blocks
  alias Klaxon.Contents
  alias Klaxon.Profiles
  alias Klaxon.Contents.Post
  alias Klaxon.Profiles.Profile

  # TODO: Replace :reject with {:reject, reason} tuple throughout module.

  @doc """
  Processes an inbound activity. The activity should have already been checked for well-formedness.
  """
  @spec process(map) :: :ok | :reject
  def process(%{} = args) do
    {activity, args} = Map.pop!(args, "activity")

    try do
      args =
        args
        |> normalize_args()
        |> tap_debug("Processed args")

      activity =
        activity
        |> maybe_normalize_id("actor")
        |> maybe_block_actor(args)
        |> dereference_actor()
        |> validate_timestamps(args)
        |> validate_signature(args)
        |> process(args)
        |> tap_debug("Processed activity")

      Logger.info("Processed good inbound activity: #{inspect(activity)}")
      :ok
    rescue
      ex ->
        Logger.error("Failed inbound activity: #{inspect(activity)}\n#{inspect(ex)}")
        Logger.error(Exception.format_stacktrace())
        {:cancel, inspect(ex)}
    catch
      :reject ->
        Logger.info("Rejected inbound activity: #{inspect(activity)}")
        :ok
    end
  end

  def process(args) do
    Logger.info("Unprocessable activity: #{inspect(args)}")
    {:cancel}
  end

  def process(%{"type" => "Create", "object" => _object} = activity, %{"profile" => %{"uri" => endpoint}} = args) do
    activity =
      activity
      |> maybe_normalize_id("object")
      |> dereference_object(args)
      |> maybe_block_object(args)
      |> validate_attributed_to_against_actor()
      |> validate_acceptability("object")
      |> tap(fn x -> Logger.debug("Processed object: #{inspect(x)}") end)

    actor_profile =
      activity
      |> Map.fetch!("actor")
      |> tap(fn x -> Logger.debug("Processed profile: #{inspect(x)}") end)

    object_post =
      activity
      |> Map.fetch!("object")
      |> Map.put(:profile, actor_profile)
      |> tap(fn x -> Logger.debug("Processed post: #{inspect(x)}") end)

    Contents.insert_or_update_public_post_profile(object_post, endpoint)
  end

  def process(activity, args) do
    Logger.info("Unprocessable\n  activity: #{inspect(activity)}\n  args: #{inspect(args)}")
    throw(:reject)
  end

  # TODO: Make this unnecessary by preprocessing headers
  # into a map in `Klaxon.Activities.Inbox.Sync` (or earlier).
  defp normalize_args(args) do
    args
    |> Map.put(
      "headers",
      Enum.map(Map.get(args, "headers", []), fn x -> List.to_tuple(x) end)
    )
  end

  defp maybe_normalize_id(%{} = object, key) do
    if attr = Map.get(object, key) do
      id = validate_publicly_dereferencable_uri(attr)

      unless id == attr do
        object |> Map.put(key, id)
      end || object
    else
      Logger.debug("Unable to normalize `id` of #{key} from: #{inspect(object)}")
      throw(:reject)
    end
  end

  defp validate_publicly_dereferencable_uri(id) when is_binary(id) do
    case URI.new(id) do
      {:ok, uri} ->
        unless uri.scheme in ["http", "https"] and uri.host do
          Logger.debug("Scheme '#{uri.scheme}' not a publicly dereferencable URI: #{id}")
          throw(:reject)
        end || id

      _ ->
        Logger.debug("Not a valid URI: #{id}")
        throw(:reject)
    end
  end

  defp validate_publicly_dereferencable_uri(%{"id" => id}) when is_binary(id) do
    validate_publicly_dereferencable_uri(id)
  end

  defp validate_publicly_dereferencable_uri(%{} = obj) do
    Logger.debug("Unable to validate as publicly dereferencable: #{inspect(obj)}")
    throw(:reject)
  end

  defp validate_timestamps(
         activity,
         %{"headers" => headers, "requested_at" => requested_at} = args
       )
       when is_list(headers) do
    Logger.debug("Verifying timestamps in args: #{inspect(args)}")

    requested_at = NaiveDateTime.from_iso8601!(requested_at)
    {_, signed_at} = List.keyfind(headers, "date", 0)
    {:ok, signed_at} = Timex.parse(signed_at, "{RFC1123}")
    diff = Timex.diff(signed_at, requested_at, :seconds)

    Logger.debug("Message requested at: #{requested_at}")
    Logger.debug("Message signed at: #{signed_at}")
    Logger.debug("Timestamps different by: #{diff} seconds")

    # TODO: Make this configurable.
    if abs(diff) > 30 do
      Logger.debug("Timestamps different by greater than allowed tolerance")
      throw(:reject)
    end

    activity
  end

  # TODO: implement
  defp validate_signature(activity, %{"headers" => headers} = args) do
    Logger.debug("verifying signature in args #{inspect(args)}")

    {_, signature} = List.keyfind(headers, "signature", 0)
    signature = HTTPSignatures.split_signature(signature)

    sig_headers = signature["headers"] -- ["(request-target)"]

    headers_map =
      Enum.reduce(sig_headers, %{}, fn x, acc ->
        {_, val} = List.keyfind(headers, x, 0)
        Map.put(acc, x, val)
      end)
      |> Map.put("(request-target)", "#{args["method"]} #{args["path"]}")

    # headers = headers ++ {"(request-target)", "#{args["method"]} #{args["path"]}"}

    public_key =
      activity
      |> Map.get("actor", %{})
      |> Map.get(:public_key)

    # TODO: Check against multiple keys, not just first.
    public_key_decoded =
      :public_key.pem_decode(public_key)
      |> List.first()
      |> :public_key.pem_entry_decode()

    Logger.debug("Verify signature headers: #{inspect(headers_map)}")
    Logger.debug("Verify signature signature: #{inspect(signature)}")
    Logger.debug("Verify signature public key: #{inspect(public_key)}")

    valid? = HTTPSignatures.validate(headers_map, signature, public_key_decoded)

    # TODO: Should reject if signature validation fails.
    Logger.debug("Verify signature pass? #{valid?}")

    activity
  end

  defp maybe_block_actor(
         %{"actor" => actor_uri} = activity,
         %{"profile" => %{"id" => profile_id}} = _args
       ) do
    if Blocks.actor_blocked?(actor_uri, profile_id) do
      Logger.debug("Actor blocked: #{actor_uri}")
      throw(:reject)
    end || activity
  end

  defp maybe_block_object(
         %{"object" => object} = activity,
         %{"profile" => %{"id" => profile_id}} = _args
       ) do
    if Blocks.object_blocked?(object, profile_id) do
      Logger.debug("Object blocked: #{inspect(object)}")
      throw(:reject)
    end || activity
  end

  defp validate_attributed_to_against_actor(
         %{"actor" => %{uri: actor_uri}, "object" => %{attributed_to: attributed_to}} = activity
       ) do
    unless actor_uri == attributed_to do
      Logger.debug("Failed to verify `attributed_to` against `actor`: #{activity}")
      throw(:reject)
    end || activity
  end

  defp validate_attributed_to_against_actor(activity) do
    Logger.debug("Unable to verify `attributed_to` against `actor`: #{activity}")
    throw(:reject)
  end

  # TODO: This is a stub.
  # Implementing this depends on items not yet created.
  defp validate_acceptability(activity, _attribute) do
    activity
  end

  defp dereference_actor(activity) do
    actor_uri = Map.fetch!(activity, "actor")

    profile =
      actor_uri
      |> Profiles.get_or_fetch_public_profile_by_uri()
      |> Profile.to_map()
      |> throw_reject_if_false()
      |> maybe_re_dereference(actor_uri, &Profiles.get_public_profile_by_uri/1)

    Logger.debug("Dereferenced actor: #{actor_uri}\n  profile: #{inspect(profile)}")
    Map.put(activity, "actor", profile)
  end

  defp dereference_object(%{"object" => object_uri} = activity, %{"profile" => profile} = _args)
       when is_binary(object_uri) do
    post =
      object_uri
      |> Contents.get_or_fetch_public_post_by_uri(profile)
      |> Post.to_map()
      |> throw_reject_if_false()
      |> maybe_re_dereference(object_uri, &Contents.get_public_post_by_uri/1)

    Logger.debug("Dereferenced object: #{object_uri}\n  post: #{inspect(post)}")
    Map.put(activity, "object", post)
  end

  defp maybe_re_dereference(%{id: _id} = entity, _entity_uri, _fun) do
    entity
  end

  defp maybe_re_dereference(%{uri: canonical_uri} = entity, entity_uri, fun) do
    # Because we may have fetched a public entity with a different
    # canonical `id` due to an HTTP redirect, attempt to re-get the entity
    # from the repository.
    unless canonical_uri == entity_uri do
      if re_get_entity = fun.(canonical_uri) do
        Map.put(entity, :id, Map.get(re_get_entity, :id))
      end
    end || entity
  end

  defp throw_reject_if_false(arg) do
    unless arg do
      Logger.debug("false object rejected")
      throw(:reject)
    end || arg
  end

  # TODO: Should probably be a helper.
  defp tap_debug(arg, msg) do
    Logger.debug("#{msg}: #{inspect(arg)}")
    arg
  end
end
