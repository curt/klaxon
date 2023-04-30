defmodule Klaxon.Syndication do
  require Logger
  alias Klaxon.Repo
  alias Klaxon.Contents.Post
  alias Klaxon.Syndication.Subscription
  alias Klaxon.Mailer
  # FIXME!
  alias KlaxonWeb.Helpers
  alias Swoosh.Email
  import Ecto.Query

  @mail_offset 30

  def get_subscribers(schedule) do
    case from(s in Subscription, where: not is_nil(s.confirmed_at) and s.schedule == ^schedule)
         |> Repo.all() do
      subscribers when is_list(subscribers) -> {:ok, subscribers}
      _ -> {:error, :not_found}
    end
  end

  def get_subscriber(id) do
    case from(s in Subscription, where: not is_nil(s.confirmed_at) and s.id == ^id)
         |> Repo.one() do
      %Subscription{} = subscriber -> {:ok, subscriber}
      _ -> {:error, :not_found}
    end
  end

  def get_subscriber(id, key) do
    case from(s in Subscription,
           where: not is_nil(s.confirmed_at) and s.id == ^id and s.key == ^key
         )
         |> Repo.one() do
      %Subscription{} = subscriber -> {:ok, subscriber}
      _ -> {:error, :not_found}
    end
  end

  def get_any_subscriber(id, key) do
    case from(s in Subscription,
           where: s.id == ^id and s.key == ^key
         )
         |> Repo.one() do
      %Subscription{} = subscriber -> {:ok, subscriber}
      _ -> {:error, :not_found}
    end
  end

  def insert_subscriber(attrs, sender, conf_url_fun) when is_function(conf_url_fun, 2) do
    with {:ok, subscriber} <- Repo.insert(Subscription.changeset(%Subscription{}, attrs)) do
      send_confirmation_to_subscriber(
        subscriber,
        sender,
        conf_url_fun.(subscriber.id, subscriber.key)
      )
    end
  end

  def update_subscriber(id, key, attrs) do
    case from(s in Subscription, where: s.id == ^id and s.key == ^key)
         |> Repo.one() do
      %Subscription{} = subscriber ->
        Repo.update(Subscription.update_changeset(subscriber, attrs))

      _ ->
        {:error, :not_found}
    end
  end

  def send_confirmation_to_subscriber(%Subscription{} = subscriber, sender, url) do
    email =
      Email.new()
      |> Email.to(subscriber.email)
      |> Email.from(sender)
      |> Email.subject("Your confirmation required from #{host()}")
      |> Email.html_body(confirmation_html(subscriber, url))
      |> Email.text_body(confirmation_text(subscriber, url))

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def confirmation_text(%Subscription{} = subscriber, url) do
    """

    ==============================

    Hi #{subscriber.email},

    Before receiving post digests from #{host()}, you must confirm this
    e-mail address by clicking the link below.

    If the link is not clickable, you may copy and paste the link
    into the address bar of your browser.

    #{url}

    ==============================

    """
  end

  def confirmation_html(%Subscription{} = subscriber, url) do
    """
    <hr>
    <p>Hi #{subscriber.email},</p>
    <p>Before receiving post digests from #{host()}, you must confirm this
    e-mail address by clicking the link below.</p>
    <p>If the link is not clickable, you may copy and paste the link
    into the address bar of your browser.</p>
    <p><a href="#{url}">#{url}</a></p>
    <hr>
    """
  end

  def confirm_subscriber(id, key) do
    with {:ok, %Subscription{} = subscriber} <- get_any_subscriber(id, key) do
      Repo.update(Subscription.confirm_changeset(subscriber, %{confirmed_at: DateTime.utc_now()}))
    end
  end

  def delete_subscriber(id, key) do
    with {:ok, %Subscription{} = subscriber} <- get_any_subscriber(id, key) do
      Repo.delete(Subscription.changeset(subscriber, %{}))
    end
  end

  def get_posts_for_subscriber(%Subscription{} = subscriber) do
    begin_at = subscriber.last_published_at || subscriber.confirmed_at || subscriber.inserted_at
    end_at = DateTime.utc_now() |> end_at_offset()

    case Post.from_preloaded()
         |> Post.where_status([:published])
         |> Post.where_origin([:local])
         |> Post.where_visibility([:public])
         |> where([posts: p], not is_nil(p.published_at))
         |> where([posts: p], p.published_at > ^begin_at)
         |> where([posts: p], p.published_at <= ^end_at)
         |> Repo.all() do
      posts when is_list(posts) -> {:ok, Enum.sort_by(posts, & &1.published_at, DateTime)}
      _ -> {:error, :not_found}
    end
  end

  def send_digest_to_subscriber(%Subscription{} = subscriber, posts) do
    email =
      Email.new()
      |> Email.to(subscriber.email)
      |> Email.from(sender())
      |> Email.subject("Your latest digest from #{host()}")
      |> Email.html_body(digest_html(subscriber, posts))
      |> Email.text_body(digest_text(subscriber, posts))

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def update_subscriber_from_posts(%Subscription{} = subscriber, posts) do
    last_post = List.last(posts)
    changeset = Subscription.changeset(subscriber, %{last_published_at: last_post.published_at})
    Repo.update(changeset)
  end

  def digest_text(%Subscription{} = subscriber, posts) do
    edit_url = edit_subscription_url(subscriber.id, subscriber.key)
    delete_url = delete_subscription_url(subscriber.id, subscriber.key)

    header = """

    ==============================

    Hi #{subscriber.email},

    Links to the most recent posts from #{host()} can be found below.

    Enjoy!

    ==============================

    """

    body =
      Enum.join(
        Enum.map(
          posts,
          fn post ->
            "#{Helpers.prettify_date(post.published_at)}\n#{Helpers.snippet(post)}\n#{post.uri}"
          end
        ),
        "\n\n"
      ) <> "\n"

    footer = """

    ==============================

    Use the following link to edit your subscription:
    #{edit_url}

    Use the following link to delete your subscription:
    #{delete_url}

    ==============================

    Please do not reply to this message.
    """

    header <> body <> footer
  end

  def digest_html(%Subscription{} = subscriber, posts) do
    edit_url = edit_subscription_url(subscriber.id, subscriber.key)
    delete_url = delete_subscription_url(subscriber.id, subscriber.key)

    header = """
    <hr>
    <p>Hi #{subscriber.email},</p>
    <p>Links to the most recent posts from #{host()} can be found below.</p>
    <p>Enjoy!</p>
    <hr>
    """

    body =
      Enum.join(
        Enum.map(
          posts,
          fn post ->
            "<p>#{Helpers.prettify_date(post.published_at)}<br>" <>
              "#{Helpers.snippet(post)}<br><a href=\"#{post.uri}\">#{post.uri}</a></p>\n"
          end
        )
      )

    footer = """
    <hr>
    <p>Use the following link to edit your subscription:<br>
    <a href="#{edit_url}">#{edit_url}</a></p>
    </p>
    <p>Use the following link to delete your subscription:<br>
    <a href="#{delete_url}">#{delete_url}</a></p>
    </p>
    <p>
    </p>
    <hr>
    <p>Please do not reply to this message.</p>
    """

    header <> body <> footer
  end

  defp end_at_offset(datetime) do
    DateTime.add(datetime, -@mail_offset, :minute)
  end

  # FIXME! Heinous kludges follow.
  defp edit_subscription_url(id, key) do
    KlaxonWeb.Router.Helpers.subscription_url(endpoint(), :edit, id, key)
  end

  defp delete_subscription_url(id, key) do
    KlaxonWeb.Router.Helpers.subscription_url(endpoint(), :delete, id, key)
  end

  defp sender(), do: {"Klaxon", "klaxon@#{host()}"}
  defp host(), do: endpoint().host
  defp endpoint(), do: KlaxonWeb.Endpoint.struct_url()
end
