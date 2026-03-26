# frozen_string_literal: true

require_relative "lib/wrap_it_ruby/version"

Gem::Specification.new do |spec|
  spec.name        = "wrap_it_ruby"
  spec.version     = WrapItRuby::VERSION
  spec.authors     = ["Nathan Kidd"]
  spec.email       = ["nathankidd@hey.com"]
  spec.homepage    = "https://github.com/n-at-han-k/wrap-it-ruby"
  spec.summary     = "Rails engine for iframe-based reverse proxy portals"
  spec.description = "Wraps upstream web applications in an iframe via a same-origin reverse proxy. " \
                     "Provides Rack middleware for proxying, script injection, and root-relative URL rewriting, " \
                     "plus Stimulus controllers for browser history synchronisation."
  spec.license     = "Apache-2.0"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails",           ">= 8.0"
  spec.add_dependency "importmap-rails"
  spec.add_dependency "stimulus-rails"
  spec.add_dependency "async-http"
  spec.add_dependency "async-websocket"
  spec.add_dependency "rails-active-ui"
  spec.add_dependency "emoji-validator-rails"
end
