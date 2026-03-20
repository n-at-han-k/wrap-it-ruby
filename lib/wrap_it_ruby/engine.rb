# frozen_string_literal: true

require "ui"
require "wrap_it_ruby/middleware/proxy_middleware"
require "wrap_it_ruby/middleware/root_relative_proxy_middleware"
require "wrap_it_ruby/middleware/script_injection_middleware"

module WrapItRuby
  class Engine < ::Rails::Engine
    isolate_namespace WrapItRuby

    # Insert proxy middleware early — before Rails routing — so /_proxy/*
    # requests never hit ActionDispatch at all.
    #
    # Order: RootRelativeProxy -> ScriptInjection -> Proxy
    #   1. RootRelativeProxy rewrites root-relative paths to /_proxy/{host}
    #   2. ScriptInjection strips Accept-Encoding, passes to Proxy,
    #      then injects <base> + interception.js into HTML responses
    #   3. Proxy does the actual upstream proxying
    initializer "wrap_it_ruby.middleware" do |app|
      app.middleware.insert_before ActionDispatch::Static, WrapItRuby::Middleware::RootRelativeProxyMiddleware
      app.middleware.insert_after  WrapItRuby::Middleware::RootRelativeProxyMiddleware, WrapItRuby::Middleware::ScriptInjectionMiddleware
      app.middleware.insert_after  WrapItRuby::Middleware::ScriptInjectionMiddleware,   WrapItRuby::Middleware::ProxyMiddleware
    end

    # Register importmap pins for the Stimulus controller
    initializer "wrap_it_ruby.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << Engine.root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers << Engine.root.join("app/javascript")
      end
    end

    # Add engine assets to the asset load path (for propshaft/sprockets)
    initializer "wrap_it_ruby.assets" do |app|
      app.config.assets.paths << Engine.root.join("app/assets/javascripts")
      app.config.assets.paths << Engine.root.join("app/assets/stylesheets")
    end

    # Make engine helpers (MenuHelper, IframeHelper) available in host app views.
    # MenuHelper#render_menu depends on ComponentHelper from rails-active-ui,
    # which is already injected into ActionView by the Ui engine.
    initializer "wrap_it_ruby.helpers" do
      ActiveSupport.on_load(:action_view) do
        include WrapItRuby::MenuHelper
        include WrapItRuby::IframeHelper
      end
    end
  end
end
