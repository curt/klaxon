defmodule KlaxonWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Klaxon.Auth
  alias Klaxon.Auth.User
  alias KlaxonWeb.Router.Helpers, as: Routes

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_klaxon_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.
  """
  def log_in_user(conn, user, params \\ %{}) do
    user_return_to = get_session(conn, :user_return_to)
    {conn, token} = do_log_in(conn, user, params)

    conn
    |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  @spec log_in_user_api(Plug.Conn.t(), atom() | %{:id => any(), optional(any()) => any()}, any()) ::
          Plug.Conn.t()
  def log_in_user_api(conn, user, params \\ %{}) do
    {conn, _token} = do_log_in(conn, user, params)
    conn
  end

  defp do_log_in(conn, user, params) do
    token = Auth.generate_user_session_token(user)

    conn =
      conn
      |> renew_session()
      |> put_session(:user_token, token)
      |> maybe_write_remember_me_cookie(token, params)

    {conn, token}
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    conn
    |> do_log_out()
    |> redirect(to: "/")
  end

  def log_out_user_api(conn) do
    do_log_out(conn)
  end

  defp do_log_out(conn) do
    if user_token = get_session(conn, :user_token) do
      Auth.delete_session_token(user_token)
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Auth.get_user_by_session_token(user_token)
    assign(conn, :current_user, user)
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(
        %Plug.Conn{assigns: %{current_user: %User{} = _user}} = conn,
        _opts
      ) do
    conn
  end

  def require_authenticated_user(%Plug.Conn{private: %{:phoenix_format => "html"}} = conn, _opts) do
    conn
    |> put_flash(:error, "You must log in to access this page.")
    |> maybe_store_return_to()
    |> redirect(to: Routes.user_session_path(conn, :new))
    |> halt()
  end

  def require_authenticated_user(conn, _opts) do
    conn
    |> put_status(:not_found)
    |> put_view(KlaxonWeb.ErrorView)
    |> render(:"401")
    |> halt()
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"
end
