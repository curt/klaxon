defmodule Klaxon.Activities.Helpers do
  alias Klaxon.Snippet

  def contextify() do
    %{"@context": "https://www.w3.org/ns/activitystreams"}
  end

  def contextify(%{} = object) do
    Map.merge(object, contextify())
  end

  def mergify(%{} = object, _key, nil) do
    object
  end

  def mergify(%{} = object, _key, []) do
    object
  end

  def mergify(%{} = object, key, val) do
    Map.put(object, key, val)
  end

  def stampify(datetime) do
    Timex.format!(datetime, "{RFC3339z}")
  end

  def snippet(%{title: title, source: source, content_html: content_html} = object) do
    title ||
      Snippet.snippify(
        source ||
          textify(content_html) ||
          captions(object) ||
          "",
        140
      )
  end

  def snippet(attachment) do
    Snippet.snippify(attachment.caption, 140)
  end

  def textify(html) when is_binary(html) do
    Floki.parse_fragment!(html)
    |> Floki.text()
  end

  def textify(_), do: nil

  def htmlify(%{caption: caption}) when not is_nil(caption) do
    htmlify(caption)
  end

  def htmlify(markdown) when is_binary(markdown) do
    Earmark.as_html!(markdown, inner_html: true, compact_output: true)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  def htmlify(_), do: nil

  def captions(%{attachments: attachments}) do
    Enum.reduce(attachments, "", fn x, acc -> acc <> "\n\n" <> (x.caption || "") end)
  end
end
