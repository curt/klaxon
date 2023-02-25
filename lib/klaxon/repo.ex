defmodule Klaxon.Repo do
  use Ecto.Repo,
    otp_app: :klaxon,
    adapter: Ecto.Adapters.Postgres
end
