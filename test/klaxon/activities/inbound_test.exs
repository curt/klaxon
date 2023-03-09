defmodule Klaxon.Activities.InboundTest do
  use ExUnit.Case
  alias Klaxon.Activities.Inbox.Sync

  @good_payload %{
    "actor" => "https://example.com/actor/joe",
    "type" => "Create"
  }

  @good_req_headers [
    {"date", "Thu, 05 Jan 2014 21:31:40 GMT"},
    {"signature",
     "keyId=\"Test\",algorithm=\"rsa-sha256\"," <>
       "headers=\"(request-target) host date\",signature=\"HUxc9BS3P/kPhS\""},
    {"host", "example.com"}
  ]

  describe "`Klaxon.Activities.Sync.request_well_formed?`" do
    test "with all good arguments" do
      assert Sync.request_well_formed?(@good_payload, @good_req_headers)
    end

    test "with `payload` not map" do
      refute Sync.request_well_formed?(1, @good_req_headers)
    end

    test "with `payload` nil" do
      refute Sync.request_well_formed?(nil, @good_req_headers)
    end

    test "with `req_headers` not list" do
      refute Sync.request_well_formed?(@good_payload, 1)
    end

    test "with `req_headers` empty list" do
      refute Sync.request_well_formed?(@good_payload, [])
    end

    test "with `req_headers` nil" do
      refute Sync.request_well_formed?(@good_payload, nil)
    end

    test "with missing `actor` in payload" do
      refute Sync.request_well_formed?(
               @good_payload |> Map.delete("actor"),
               @good_req_headers
             )
    end

    test "with missing `type` in payload" do
      refute Sync.request_well_formed?(
               @good_payload |> Map.delete("type"),
               @good_req_headers
             )
    end

    test "with bad `type` in payload" do
      refute Sync.request_well_formed?(
               @good_payload |> Map.put("type", "Explode"),
               @good_req_headers
             )
    end

    test "with missing `date` in req_headers" do
      refute Sync.request_well_formed?(
               @good_payload,
               @good_req_headers |> remove_pair("date")
             )
    end

    test "with bad `date` (invalid hour) in req_headers" do
      refute Sync.request_well_formed?(
               @good_payload,
               @good_req_headers |> replace_pair("date", "Thu, 05 Jan 2014 25:31:40 GMT")
             )
    end

    test "with bad `date` (missing time zone) in req_headers" do
      refute Sync.request_well_formed?(
               @good_payload,
               @good_req_headers |> replace_pair("date", "Thu, 05 Jan 2014 21:31:40")
             )
    end

    test "with bad `date` (invalid day of week) in req_headers" do
      refute Sync.request_well_formed?(
               @good_payload,
               @good_req_headers |> replace_pair("date", "Bad, 05 Jan 2014 21:31:40 GMT")
             )
    end

    test "with missing `signature` in req_headers" do
      refute Sync.request_well_formed?(
               @good_payload,
               @good_req_headers |> remove_pair("signature")
             )
    end
  end

  defp remove_pair(tuple_list, key) do
    tuple_list |> List.keydelete(key, 0)
  end

  defp replace_pair(tuple_list, key, value) do
    (tuple_list |> remove_pair(key)) ++ [{key, value}]
  end
end
