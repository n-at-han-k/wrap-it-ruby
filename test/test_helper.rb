# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "rack/test"

# Minimal Rails boot — just enough for the engine to load without a full app.
ENV["RAILS_ENV"] = "test"

require "rails"
require "action_controller/railtie"

# Tiny dummy app so the engine can mount.
class DummyApp < Rails::Application
  config.eager_load = false
  config.hosts.clear
  config.secret_key_base = "test-secret-key-base-that-is-long-enough"

  # Provide a stub assets config so the engine's asset initializer doesn't blow up.
  config.assets = ActiveSupport::OrderedOptions.new
  config.assets.paths = []
end

require "wrap_it_ruby"

DummyApp.initialize!

FIXTURES_PATH = File.expand_path("fixtures", __dir__)
