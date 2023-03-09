defmodule Klaxon.Activities.Inbound do
  require Logger

  alias Klaxon.Profiles.Profile

  @minimal_attrs ~w(actor type)
  @minimal_headers ~w(host date)
  @valid_types ~w(Accept Add Announce Arrive Block Create Delete Dislike Flag
                  Follow Ignore Invite Join Leave Like Listen Move Offer Question
                  Reject Read Remove TentativeReject TentativeAccept Travel Undo
                  Update View)

  @doc """
  Returns whether or not the inbound activity request is well-formed.
  """
  @spec request_well_formed?(map, list) :: boolean
  def request_well_formed?(%{} = payload, [_ | _] = headers) do
    cond do
      !payload_is_well_formed?(payload) ->
        Logger.debug("payload not well formed\n  headers: #{inspect(payload)}")
        false

      !headers_is_well_formed?(headers) ->
        Logger.debug("headers not well formed\n  headers: #{inspect(headers)}")
        false

      !signature_is_well_formed?(headers) ->
        Logger.debug("signature not well formed\n  headers: #{inspect(headers)}")
        false

      true ->
        true
    end
  end

  def request_well_formed?(_, _) do
    false
  end

  @spec payload_is_well_formed?(map) :: boolean
  defp payload_is_well_formed?(payload) do
    cond do
      !payload_has_minimal_attrs?(payload) -> false
      !payload_has_valid_type?(payload) -> false
      true -> true
    end
  end

  @spec payload_has_minimal_attrs?(map) :: boolean
  defp payload_has_minimal_attrs?(payload) do
    payload_keys = Map.keys(payload)
    Enum.all?(@minimal_attrs, fn attr -> attr in payload_keys end)
  end

  @spec payload_has_valid_type?(map) :: boolean
  defp payload_has_valid_type?(payload) do
    payload["type"] in @valid_types
  end

  @spec headers_is_well_formed?(list) :: boolean
  defp headers_is_well_formed?(headers) do
    cond do
      !headers_has_minimal_attrs?(headers) -> false
      !headers_has_valid_date?(headers) -> false
      true -> true
    end
  end

  @spec headers_has_minimal_attrs?(list) :: boolean
  defp headers_has_minimal_attrs?(headers) do
    # Get the key from each tuple.
    keys = Enum.map(headers, fn x -> elem(x, 0) end)
    attrs = @minimal_headers ++ ["signature"]
    # Make sure the required headers are present in the list of keys.
    Enum.all?(attrs, fn attr -> attr in keys end)
  end

  defp headers_has_valid_date?(headers) do
    case List.keyfind(headers, "date", 0) do
      {"date", date} ->
        date_is_valid_rfc1123?(date)

      _ ->
        Logger.debug("invalid date\n  headers: #{inspect(headers)}")
        false
    end
  end

  defp date_is_valid_rfc1123?(date) do
    case Timex.parse(date, "{RFC1123}") do
      {:ok, _result} -> true
      _ -> false
    end
  end

  @spec signature_is_well_formed?(list) :: boolean
  defp signature_is_well_formed?(headers) do
    case List.keyfind(headers, "signature", 0) do
      {"signature", signature} ->
        signature_has_minimal_attrs?(signature)

      _ ->
        Logger.debug("signature not found in headers\n  headers: #{inspect(headers)}")
        false
    end
  end

  @spec signature_has_minimal_attrs?(binary) :: boolean
  defp signature_has_minimal_attrs?(signature) do
    # Extract the headers from the signature request header value.
    signature_split = HTTPSignatures.split_signature(signature)
    signature_headers = signature_split["headers"]
    # At a minimum, the signature headers should include all the required request headers,
    # as well as the special header `(request-target)`.
    attrs = @minimal_headers ++ ["(request-target)"]
    Enum.all?(attrs, fn attr -> attr in signature_headers end)
  end

  def worker_args(params, conn, requested_at) do
    %{
      activity: params,
      headers: Enum.map(conn.req_headers, fn x -> Tuple.to_list(x) end),
      host: conn.host,
      method: String.downcase(conn.method),
      path: conn.request_path,
      requested_at: requested_at,
      profile_id: conn.assigns[:current_profile].id
    }
  end

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

  # def process(%{} = activity, _profile_id) do
  #   # Catch-all function for unprocessable activity.
  #   Logger.info("Unable to process activity: #{inspect(activity)}")
  #   :reject
  # end

  # defp maybe_reference_actor_id(%{"actor" => _actor} = activity) do
  #   maybe_reference_id(activity, "actor")
  # end

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
