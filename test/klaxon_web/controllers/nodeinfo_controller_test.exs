defmodule KlaxonWeb.NodeInfoControllerTest do
  use KlaxonWeb.ConnCase

  describe "nodeinfo controller" do
    test "well known", %{conn: conn} do
      conn = get(conn, Routes.node_info_path(conn, :well_known))
      json_response(conn, 200)
    end

    test "version 2.0", %{conn: conn} do
      conn = get(conn, Routes.node_info_path(conn, :version, "2.0"))
      json_response(conn, 200)
    end
  end
end
