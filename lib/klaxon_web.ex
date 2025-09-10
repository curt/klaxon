defmodule KlaxonWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use KlaxonWeb, :controller
      use KlaxonWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [
          html: "View",
          json: "View",
          "activity+json": "View"
        ]

      import Plug.Conn
      import KlaxonWeb.Gettext
      import KlaxonWeb.Helpers
      alias KlaxonWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/klaxon_web/templates",
        namespace: KlaxonWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {KlaxonWeb.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(view_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      use Phoenix.HTML
      import KlaxonWeb.ErrorHelpers
      import KlaxonWeb.Gettext
      import KlaxonWeb.Helpers
      alias KlaxonWeb.Router.Helpers, as: Routes

      # Allow calling render "partial.html", assigns inside templates
      def render(template, assigns) when is_binary(template) and is_map(assigns) do
        Phoenix.View.render(__MODULE__, template, assigns)
      end

      # Allow calling render SomeView, "template.html", assigns
      def render(module, template, assigns)
          when is_atom(module) and is_binary(template) and is_map(assigns) do
        Phoenix.View.render(module, template, assigns)
      end
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import KlaxonWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView and HEEx helpers/components
      import Phoenix.LiveView.Helpers
      import Phoenix.Component

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import KlaxonWeb.ErrorHelpers
      import KlaxonWeb.Gettext
      import KlaxonWeb.Helpers
      alias KlaxonWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
