# frozen_string_literal: true

WrapItRuby::Engine.routes.draw do
  root "home#index"

  get "/*path", to: "proxy#show", constraints: ->(req) {
    WrapItRuby::Menu.proxy_paths.any? { |p| req.path.start_with?(p) }
  }
end
