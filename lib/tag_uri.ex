defmodule TagUri do
  def generate(authority, specific) do
    date = Timex.format!(Timex.now(), "{ISOdate}")
    "tag:#{authority},#{date}:#{specific}"
  end
end
