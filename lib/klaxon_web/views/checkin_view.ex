defmodule KlaxonWeb.CheckinView do
  use KlaxonWeb, :view

  def status_action(%{status: status}) do
    case status do
      :draft -> "drafted"
      :published -> "checked in"
      _ -> "appeared"
    end
  end

  def status_date(%{status: status} = checkin) do
    case status do
      _ -> checkin.checked_in_at
    end
  end
end
