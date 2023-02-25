# FIXME: This module is redundant since PageController is going away.
defmodule KlaxonWeb.PageControllerTest do
  use KlaxonWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Klaxon"
  end
end
