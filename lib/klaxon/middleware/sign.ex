defmodule Klaxon.Middleware.Sign do
  require Logger

  @behaviour Tesla.Middleware
  @http_date "{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT"

  @spec call(Tesla.Env.t(), Tesla.Env.stack(), any) :: Tesla.Env.result()
  def call(env, next, _options) do
    env
    |> sign()
    |> Tesla.run(next)
  end

  @spec sign(Tesla.Env.t()) :: Tesla.Env.t()
  def sign(
        %Tesla.Env{
          method: :post,
          url: url,
          body: body,
          opts: [private_key: private_key, key_id: key_id]
        } = env
      ) do
    {host, path} = host_port_path(url)

    date = Timex.format!(Timex.now(), @http_date)
    digest = "SHA-256=" <> (:crypto.hash(:sha256, body) |> Base.encode64())
    length = byte_size(body)
    target = "post #{path}"

    signature_headers = %{
      "(request-target)" => target,
      "host" => host,
      "date" => date,
      "digest" => digest,
      "content-length" => length
    }

    private_key_decoded =
      :public_key.pem_decode(private_key)
      |> List.first()
      |> :public_key.pem_entry_decode()

    signature = HTTPSignatures.sign(private_key_decoded, key_id, signature_headers)

    env
    |> Tesla.put_headers([{"date", date}, {"digest", digest}, {"signature", signature}])
  end

  def sign(env) do
    env
  end

  defp host_port_path(url) do
    %{host: host, scheme: scheme, port: port, path: path} = URI.new!(url)

    if port == URI.default_port(scheme) do
      {host, path}
    else
      {"#{host}:#{port}", path}
    end
  end
end
