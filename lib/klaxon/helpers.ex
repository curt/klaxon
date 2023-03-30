defmodule Klaxon.Helpers do
  @spec decompose_media_object(map | binary) :: {binary | nil, any}
  def decompose_media_object(%{"url" => url, "mediaType" => media_type})
      when is_binary(url) and is_binary(media_type) do
    {url, media_type}
  end

  def decompose_media_object(%{"url" => url}) when is_binary(url) do
    {url, nil}
  end

  def decompose_media_object(object) when is_binary(object), do: {object, nil}
  def decompose_media_object(_), do: {nil, nil}
end
