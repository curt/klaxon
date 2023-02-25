defmodule KlaxonWeb.LabelsController do
  use KlaxonWeb, :controller

  def show(conn, %{"slug" => slug}) do
    html(conn, "Stub for \"#{slug}\" label.")
  end
end
