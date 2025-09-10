defmodule KlaxonWeb.SubscriptionControllerTest do
  use KlaxonWeb.ConnCase, async: true

  alias Klaxon.Repo
  alias Klaxon.Syndication.Subscription
  alias Base58Check.Base58

  describe "subscription controller" do
    setup do
      subscription =
        Repo.insert!(%Subscription{
          email: "alice#{System.unique_integer([:positive])}@example.com",
          key: "#{System.unique_integer([:positive])}",
          schedule: :hourly
        })

      %{subscription: subscription}
    end

    test "unsubscribe with good id and key, good response", %{
      conn: conn,
      subscription: subscription
    } do
      conn =
        post(
          conn,
          Routes.subscription_path(conn, :unsubscribe, subscription.id, subscription.key),
          "List-Unsubscribe": "One-Click"
        )

      assert text_response(conn, 200)
    end

    test "unsubscribe with bad id and key, good response", %{conn: conn} do
      id = Base58.encode(:crypto.strong_rand_bytes(16))
      key = Base58.encode(:crypto.strong_rand_bytes(32))

      conn =
        post(
          conn,
          Routes.subscription_path(conn, :unsubscribe, id, key),
          "List-Unsubscribe": "One-Click"
        )

      assert text_response(conn, 200)
    end

    test "unsubscribe with good id and key, missing params, bad response", %{
      conn: conn,
      subscription: subscription
    } do
      assert_raise(
        Phoenix.ActionClauseError,
        fn ->
          post(
            conn,
            Routes.subscription_path(conn, :unsubscribe, subscription.id, subscription.key)
          )
        end
      )
    end

    test "unsubscribe with get, bad response", %{conn: conn, subscription: subscription} do
      conn =
        get(
          conn,
          Routes.subscription_path(conn, :unsubscribe, subscription.id, subscription.key)
        )

      assert response(conn, 404)
    end
  end
end
