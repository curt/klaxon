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
          Routes.subscription_path(conn, :unsubscribe, subscription.id, subscription.key)
        )

      assert text_response(conn, 200)
    end

    test "unsubscribe with bad id and key, good response", %{conn: conn} do
      id = Base58.encode(:crypto.strong_rand_bytes(16))
      key = Base58.encode(:crypto.strong_rand_bytes(32))

      conn =
        post(
          conn,
          Routes.subscription_path(conn, :unsubscribe, id, key)
        )

      assert text_response(conn, 200)
    end

    test "unsubscribe with get, bad response", %{conn: conn, subscription: subscription} do
      assert_raise(
        Phoenix.Router.NoRouteError,
        fn ->
          get(
            conn,
            Routes.subscription_path(conn, :unsubscribe, subscription.id, subscription.key)
          )
        end
      )
    end
  end
end
