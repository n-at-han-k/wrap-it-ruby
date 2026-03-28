# frozen_string_literal: true

WrapItRuby::Engine.routes.draw do
  get    'menu/settings',          to: 'menu_settings#index',   as: :menu_settings
  get    'menu/settings/new',      to: 'menu_settings#new',    as: :new_menu_setting
  post   'menu/settings',          to: 'menu_settings#create', as: :create_menu_setting
  get    'menu/settings/:id/edit', to: 'menu_settings#edit',   as: :edit_menu_setting
  get    'menu/settings/export',   to: 'menu_settings#export', as: :export_menu_settings
  patch  'menu/settings/:id',      to: 'menu_settings#update', as: :update_menu_setting
  patch  'menu/settings/:id/sort', to: 'menu_settings#sort',   as: :sort_menu_setting
  delete 'menu/settings/:id',      to: 'menu_settings#destroy', as: :destroy_menu_setting

  get '/*path', to: 'proxy#show', constraints: lambda { |req|
    WrapItRuby::MenuHelper.proxy_route?(req.path)
  }
end
