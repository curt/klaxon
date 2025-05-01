defmodule KlaxonWeb.Helpers do
  import KlaxonWeb.Titles
  alias Klaxon.Checkins.Checkin
  alias Klaxon.Contents.Place
  alias Klaxon.Profiles.Profile
  alias Klaxon.Contents.Post
  alias Klaxon.Contents.PostAttachment
  alias Klaxon.Snippet
  alias KlaxonWeb.Router.Helpers, as: Routes

  @moduledoc """
  Provides helper functions for web app.
  """

  @doc """
  Returns `Map` with ActivityStream `@context` key and appropriate value.
  """
  @spec contextify() :: map
  def contextify() do
    %{"@context": "https://www.w3.org/ns/activitystreams"}
  end

  @spec mergify(map, any, any) :: map
  def mergify(%{} = object, _key, nil) do
    object
  end

  def mergify(%{} = object, _key, []) do
    object
  end

  def mergify(%{} = object, key, val) do
    Map.put(object, key, val)
  end

  def prettify_date(date) do
    Timex.format!(date, "{D} {Mshort} {YYYY} {h24}:{m}")
  end

  def prettify_date(date, :short) do
    Timex.format!(date, "{D} {Mshort} {YYYY}")
  end

  def prettify_date(date, :time) do
    Timex.format!(date, "{h24}:{m}")
  end

  @doc """
  Returns a datetime in a format suitable for the HTML `time` element.

  See: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/time
  """
  @spec htmlify_date(Timex.Types.valid_datetime()) :: String.t()
  def htmlify_date(date) do
    Timex.format!(date, "{YYYY}-{0M}-{0D}T{h24}:{m}:{s}{Z:}")
  end

  @doc """
  Returns an attachment caption with Markdown processed for HTML.
  """
  def htmlify_caption(%{caption: caption}) when not is_nil(caption) do
    htmlify_markdown_string(caption)
  end

  def htmlify_caption(_), do: nil

  @spec htmlify_title(%Post{}) :: String.t()
  def htmlify_title(%Post{} = post) do
    htmlify_markdown_string(title(post))
  end

  defp htmlify_markdown_string(markdown) do
    Earmark.as_html!(markdown, inner_html: true, compact_output: true)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  @doc """
  Returns the git revision set in the application configuration.
  """
  @spec git_revision :: String.t() | nil
  def git_revision() do
    case Application.fetch_env(:klaxon, :git) do
      {:ok, keys} -> Keyword.get(keys, :revision)
      _ -> nil
    end
  end

  def profile_media_avatar_path(conn, %Profile{} = profile) do
    if !is_nil(profile.icon) do
      if media = Klaxon.Media.get_media_by_uri_scope(profile.icon, :profile) do
        Routes.media_path(conn, :show, :profile, :avatar, media.id)
      end
    end ||
      "data:image/png;base64," <> Excon.ident(profile.uri, base64: true, magnification: 8)
  end

  def endpointify(uri) do
    uri = URI.parse(uri)
    %URI{host: uri.host, scheme: uri.scheme, port: uri.port}
  end

  ### Controller helpers.
  ### TODO: These should probably get their own module.

  @spec json_status_response(Plug.Conn.t(), any, any) :: Plug.Conn.t()
  def json_status_response(conn, status, msg) do
    conn |> Plug.Conn.put_status(status) |> Phoenix.Controller.json(msg)
  end

  @spec current_profile(Plug.Conn.t()) :: {:error, :not_found} | {:ok, %Profile{}}
  def current_profile(conn) do
    case conn.assigns[:current_profile] do
      %Profile{} = profile -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end

  @spec sender(%Plug.Conn{}) :: tuple
  def sender(%Plug.Conn{} = conn) do
    {"Klaxon", "klaxon@#{conn.host}"}
  end

  @spec snippet(%PostAttachment{} | %Post{} | %Place{} | %Checkin{}) :: nil | binary
  def snippet(%Post{} = post) do
    post.title ||
      Snippet.snippify(
        post.source ||
          html_textify(post.content_html) ||
          captions(post) ||
          "",
        140
      )
  end

  def snippet(%PostAttachment{} = attachment) do
    Snippet.snippify(attachment.caption, 140)
  end

  def snippet(%Place{} = place) do
    place.title ||
      Snippet.snippify(
        html_textify(place.content_html) ||
          "",
        140
      )
  end

  def snippet(%Checkin{} = checkin) do
    Snippet.snippify(
      checkin.source ||
        html_textify(checkin.content_html) ||
        "",
      140
    )
  end

  @spec html_textify(nil | binary) :: nil | binary
  def html_textify(html) do
    if html do
      Floki.parse_fragment!(html)
      |> Floki.text()
    end
  end

  defp captions(%Post{} = post) do
    if post.attachments do
      Enum.reduce(post.attachments, "", fn x, acc -> acc <> "\n\n" <> (x.caption || "") end)
    end
  end
end
