defmodule Klaxon.Contents.PostList do
  @derive {Jason.Encoder,
           only: [
             :id,
             :published_at,
             :status,
             :title,
             :updated_at,
             :visibility
           ]}
  defstruct [
    :id,
    :published_at,
    :status,
    :title,
    :updated_at,
    :visibility
  ]
end
