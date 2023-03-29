defmodule KlaxonWeb.PingControllerTest do
  use KlaxonWeb.ConnCase

  # import Klaxon.ActivitiesFixtures

  # @create_attrs %{}
  # @update_attrs %{}
  # @invalid_attrs %{}

  # describe "index" do
  #   test "lists all pings", %{conn: conn} do
  #     conn = get(conn, Routes.ping_path(conn, :index))
  #     assert html_response(conn, 200) =~ "Pings"
  #   end
  # end

  # describe "new ping" do
  #   test "renders form", %{conn: conn} do
  #     conn = get(conn, Routes.ping_path(conn, :new))
  #     assert html_response(conn, 200) =~ "Ping"
  #   end
  # end

  # describe "create ping" do
  #   test "redirects to show when data is valid", %{conn: conn} do
  #     conn = post(conn, Routes.ping_path(conn, :create), ping: @create_attrs)

  #     assert %{id: id} = redirected_params(conn)
  #     assert redirected_to(conn) == Routes.ping_path(conn, :show, id)

  #     conn = get(conn, Routes.ping_path(conn, :show, id))
  #     assert html_response(conn, 200) =~ "Show Ping"
  #   end

  #   test "renders errors when data is invalid", %{conn: conn} do
  #     conn = post(conn, Routes.ping_path(conn, :create), ping: @invalid_attrs)
  #     assert html_response(conn, 200) =~ "New Ping"
  #   end
  # end

  # describe "delete ping" do
  #   setup [:create_ping]

  #   test "deletes chosen ping", %{conn: conn, ping: ping} do
  #     conn = delete(conn, Routes.ping_path(conn, :delete, ping))
  #     assert redirected_to(conn) == Routes.ping_path(conn, :index)

  #     assert_error_sent 404, fn ->
  #       get(conn, Routes.ping_path(conn, :show, ping))
  #     end
  #   end
  # end

  # defp create_ping(_) do
  #   ping = ping_fixture()
  #   %{ping: ping}
  # end
end
