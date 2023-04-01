defmodule KlaxonWeb.ErrorViewTest do
  use KlaxonWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.html" do
    assert render_to_string(KlaxonWeb.ErrorView, "404.html", [title: nil]) =~ "Not Found"
  end

  test "renders 404.json" do
    assert render_to_string(KlaxonWeb.ErrorView, "404.json", [title: nil]) =~ "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(KlaxonWeb.ErrorView, "500.html", []) =~ "Internal Server Error"
  end

  test "renders 500.json" do
    assert render_to_string(KlaxonWeb.ErrorView, "500.json", []) =~ "Internal Server Error"
  end
end
