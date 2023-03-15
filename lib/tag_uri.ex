defmodule TagUri do
  def generate(authority, specific) do
    date = Timex.format!(Timex.now(), "{ISOdate}")
    "tag:#{authority},#{date}:#{specific}"
  end

  def generate_random(authority, context) do
    random = Base58Check.Base58.encode(:crypto.strong_rand_bytes(16))
    specific = "#{context}/#{random}"
    generate(authority, specific)
  end
end
