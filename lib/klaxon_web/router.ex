defmodule KlaxonWeb.Router do
  use KlaxonWeb, :router

  import KlaxonWeb.UserAuth
  import KlaxonWeb.Plugs

  pipeline :none do
    plug Plug.RewriteOn, [:x_forwarded_host, :x_forwarded_port, :x_forwarded_proto]
  end

  pipeline :browser do
    plug :accepts, ["html", "json", "activity+json"]
    plug Plug.RewriteOn, [:x_forwarded_host, :x_forwarded_port, :x_forwarded_proto]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {KlaxonWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :fetch_current_profile
  end

  pipeline :api do
    plug :accepts, ["json", "activity+json"]
    plug Plug.RewriteOn, [:x_forwarded_host, :x_forwarded_port, :x_forwarded_proto]
    plug :fetch_session
    plug :fetch_current_user
    plug :fetch_current_profile
  end

  # These routes have higher priority due to potential matches below.
  scope "/", KlaxonWeb do
    pipe_through [:browser, :require_owner]

    get "/posts/new", PostController, :new
  end

  scope "/", KlaxonWeb do
    pipe_through :browser

    get "/", ProfileController, :index
    get "/posts", PostController, :index
    get "/posts/:id", PostController, :show
    get "/labels/:slug", LabelsController, :show
    get "/media/:scope/:usage/:id", MediaController, :show
    get "/.well-known/webfinger", WebfingerController, :show
    get "/.well-known/nodeinfo", NodeInfoController, :well_known
    get "/nodeinfo/:version", NodeInfoController, :version
    get "/subscriptions/new", SubscriptionController, :new
    post "/subscriptions", SubscriptionController, :create
    get "/subscriptions/:id/:key/confirm", SubscriptionController, :confirm?
    post "/subscriptions/:id/:key/confirm", SubscriptionController, :confirm
    get "/subscriptions/:id/:key/edit", SubscriptionController, :edit
    put "/subscriptions/:id/:key", SubscriptionController, :update
    patch "/subscriptions/:id/:key", SubscriptionController, :update
    get "/subscriptions/:id/:key/delete", SubscriptionController, :delete?
    post "/subscriptions/:id/:key/delete", SubscriptionController, :delete
    get "/rss", RssController, :index
  end

  scope "/", KlaxonWeb do
    pipe_through :api

    get "/inbox", InboxController, :index
    post "/inbox", InboxController, :create
    get "/outbox", OutboxController, :index
    get "/followers", FollowersController, :index
    get "/following", FollowingController, :index
  end

  scope "/", KlaxonWeb do
    pipe_through [:browser, :require_authenticated_user]
  end

  scope "/", KlaxonWeb do
    pipe_through [:browser, :require_owner]

    get "/profile/avatars/new", AvatarController, :new
    post "/profile/avatars", AvatarController, :create
    get "/profile/edit", ProfileController, :edit
    put "/profile", ProfileController, :update
    get "/posts/:id/edit", PostController, :edit
    post "/posts", PostController, :create
    put "/posts/:id", PostController, :update
    patch "/posts/:id", PostController, :update
    get "/posts/:post_id/attachments", AttachmentController, :index
    post "/posts/:post_id/attachments", AttachmentController, :create
    get "/posts/:post_id/attachments/new", AttachmentController, :new
    get "/posts/:post_id/attachments/:id/edit", AttachmentController, :edit
    get "/posts/:post_id/attachments/:id", AttachmentController, :show
    put "/posts/:post_id/attachments/:id", AttachmentController, :update
    patch "/posts/:post_id/attachments/:id", AttachmentController, :update
    get "/posts/:post_id/attachments/:id/delete", AttachmentController, :delete?
    post "/posts/:post_id/attachments/:id/delete", AttachmentController, :delete
    get "/posts/:post_id/traces", TraceController, :index
    post "/posts/:post_id/traces", TraceController, :create
    get "/posts/:post_id/traces/new", TraceController, :new
    get "/posts/:post_id/traces/:id/edit", TraceController, :edit
    get "/posts/:post_id/traces/:id", TraceController, :show
    put "/posts/:post_id/traces/:id", TraceController, :update
    patch "/posts/:post_id/traces/:id", TraceController, :update
    get "/pings", PingController, :index
    get "/pings/new", PingController, :new
    get "/pings/:id", PingController, :show
    post "/pings", PingController, :create
    get "/pongs", PongController, :index
    get "/pongs/:id", PongController, :show
    get "/media/:scope", MediaController, :index
  end

  scope "/", KlaxonWeb do
    pipe_through :none

    post "/subscriptions/:id/:key/unsubscribe", SubscriptionController, :unsubscribe
  end

  scope "/api", KlaxonWeb.Api, as: :api do
    pipe_through :api

    post "/session", SessionController, :create
  end

  scope "/api", KlaxonWeb.Api, as: :api do
    pipe_through [:api, :require_owner]

    get "/session", SessionController, :show
    delete "/session", SessionController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", KlaxonWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KlaxonWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", KlaxonWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", KlaxonWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", KlaxonWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
