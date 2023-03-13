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
      args =
        args
        |> normalize_args()
        |> tap(fn x -> Logger.debug("processed args: #{inspect(x)}") end)

      activity =
        activity
        |> maybe_normalize_id("actor")
        |> maybe_block_actor(args)
        |> dereference_actor()
        |> verify_timestamps(args)
        |> verify_signature(args)
        |> process(args)
        |> tap(fn x -> Logger.debug("processed activity: #{inspect(x)}") end)

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
      |> tap(fn x -> Logger.debug("processed object: #{inspect(x)}") end)

    actor_profile =
      activity
      |> Map.fetch!("actor")
      |> tap(fn x -> Logger.debug("processed profile: #{inspect(x)}") end)

    object_post =
      activity
      |> Map.fetch!("object")
      |> Map.put(:profile, actor_profile)
      |> tap(fn x -> Logger.debug("processed post: #{inspect(x)}") end)

    Logger.debug("attempting to insert or update post: #{inspect(object_post)}")
    Contents.insert_or_update_public_post_profile(object_post)
  end

  def process(_activity, _args) do
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

  defp verify_timestamps(activity, %{"headers" => headers, "requested_at" => requested_at} = args)
       when is_list(headers) do
    Logger.debug("verifying timestamps in args #{inspect(args)}")

    requested_at = NaiveDateTime.from_iso8601!(requested_at)
    {_, signed_at} = List.keyfind(headers, "date", 0)
    {:ok, signed_at} = Timex.parse(signed_at, "{RFC1123}")
    diff = Timex.diff(signed_at, requested_at, :seconds)

    Logger.debug("message requested at #{requested_at}")
    Logger.debug("message signed at #{signed_at}")
    Logger.debug("timestamps different by #{diff} seconds")

    # TODO: Make this configurable.
    if abs(diff) > 30 do
      Logger.debug("timestamps difference outside tolerance")
      throw(:reject)
    end

    activity
  end

  # TODO: implement
  defp verify_signature(activity, %{"headers" => headers} = args) do
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

    Logger.debug("verify signature headers #{inspect(headers_map)}")
    Logger.debug("verify signature signature #{inspect(signature)}")
    Logger.debug("verify signature public_key #{inspect(public_key)}")

    valid? = HTTPSignatures.validate(headers_map, signature, public_key_decoded)

    Logger.debug("verify signature pass? #{valid?}")

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

    Logger.debug("actor not blocked #{actor_uri}")
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

    Logger.debug("object not blocked #{inspect(object)}")
    activity
  end

  defp verify_attributed_to_against_actor(
         %{"actor" => %{uri: actor_uri}, "object" => %{attributed_to: attributed_to}} = activity
       ) do
    Logger.debug("object attributed_to #{attributed_to}")

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
      |> throw_reject_if_false()
      |> maybe_re_dereference(actor_uri, &Profiles.get_public_profile_by_uri/1)

    Logger.debug("dereferenced actor #{actor_uri} to #{inspect(profile)}")
    Map.put(activity, "actor", profile)
  end

  defp dereference_object(activity, %{"profile" => profile} = _args) do
    object_uri = Map.fetch!(activity, "object")

    post =
      object_uri
      |> Contents.get_or_fetch_public_post_by_uri(profile)
      |> Post.to_map()
      |> throw_reject_if_false()
      |> maybe_re_dereference(object_uri, &Contents.get_public_post_by_uri/1)

    Logger.debug("dereferenced object #{object_uri} to #{inspect(post)}")
    Map.put(activity, "object", post)
  end

  defp maybe_re_dereference(entity, entity_uri, fun) do
    unless Map.has_key?(entity, :id) do
      # Because we may have fetched a public entity with a different
      # canonical `id` due to an HTTP redirect, attempt to re-get the entity
      # from the repository.
      canonical_uri = Map.get(entity, :uri)

      unless entity_uri == canonical_uri do
        re_get_entity = fun.(canonical_uri)

        if re_get_entity && !Map.has_key?(entity, :id) do
          Map.put(entity, :id, Map.get(re_get_entity, :id))
        end
      end
    end || entity
  end

  defp throw_reject_if_false(arg) do
    if !arg do
      Logger.debug("false object rejected")
      throw(:reject)
    else
      arg
    end
  end
end
