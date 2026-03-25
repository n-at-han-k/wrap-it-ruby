# frozen_string_literal: true

WrapItRuby::Engine.routes.draw do
  get 'menu/settings', to: 'menu_settings#index', as: :menu_settings
  patch 'menu/settings/:id/sort', to: 'menu_settings#sort', as: :sort_menu_setting

  get '/*path', to: 'proxy#show', constraints: lambda { |req|
    WrapItRuby::MenuHelper.proxy_paths.any? { |p| req.path.start_with?(p) }
  }
end
