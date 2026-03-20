# frozen_string_literal: true

WrapItRuby::Engine.routes.draw do
  get "/*path", to: "proxy#show", constraints: ->(req) {
    WrapItRuby::MenuHelper.proxy_paths.any? { |p| req.path.start_with?(p) }
  }
end
