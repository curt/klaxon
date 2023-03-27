defmodule Klaxon.HttpClient do
  def activity_client() do
    Tesla.client([
      {Tesla.Middleware.Headers, [{"accept", "application/activity+json, application/ld+json"}]},
      {Tesla.Middleware.JSON,
       decode_content_types: ["application/activity+json", "application/ld+json"]},
      {Tesla.Middleware.FollowRedirects, max_redirects: 2},
      {Tesla.Middleware.Logger, debug: false}
    ])
  end

  def activity_get(url) do
    activity_client()
    |> Tesla.get(url)
  end

  def activity_signed_post(url, body, private_key, key_id) do
    {host, path} = host_port_path(url)
    date = Timex.format!(Timex.now(), "{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT")
    target = "post #{path}"

    signature_headers = %{
      "(request-target)" => target,
      "host" => host,
      "date" => date
    }

    private_key_decoded =
      :public_key.pem_decode(private_key)
      |> List.first()
      |> :public_key.pem_entry_decode()

    signature = HTTPSignatures.sign(private_key_decoded, key_id, signature_headers)
    opts = [headers: [{"host", host}, {"date", date}, {"signature", signature}]]

    activity_client()
    |> Tesla.post(url, body, opts)
  end

  def host_port_path(url) do
    case URI.new!(url) do
      %{scheme: "https", host: host, port: 443, path: path} -> {host, path}
      %{scheme: "http", host: host, port: 80, path: path} -> {host, path}
      %{host: host, port: port, path: path} -> {"#{host}:#{port}", path}
    end
  end
end
