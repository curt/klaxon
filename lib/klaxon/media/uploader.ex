defmodule Klaxon.Media.Uploader do
  require Logger
  use Waffle.Definition

  # Versioning is handled outside this module.
  @versions [:none]

  # Define the storage directory.
  def storage_dir(_version, {_file, {media, _usage}}) do
    "media/#{media.scope}/#{media.id}"
  end

  # Define the filename.
  def filename(_version, {_file, {media, usage}}) do
    "#{usage}.#{List.first(MIME.extensions(media.mime_type))}"
  end

  # Define custom headers for S3 objects.
  def s3_object_headers(_version, {_file, {media, _usage}}) do
    [content_type: media.mime_type, cache_control: "public, max-age=31536000, immutable"]
  end
end
