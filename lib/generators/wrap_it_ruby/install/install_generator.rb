# frozen_string_literal: true

module WrapItRuby
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install WrapItRuby into the host application"

      def copy_menu_config
        template "menu.yml", "config/menu.yml"
      end

      def mount_engine_routes
        route 'mount WrapItRuby::Engine, at: "/"'
      end

      def show_post_install_message
        say ""
        say "WrapItRuby installed!", :green
        say ""
        say "  1. Edit config/menu.yml to configure your proxy routes"
        say "  2. Make sure your ApplicationController defines authenticate_user!"
        say "  3. Include wrap_it_ruby/application.css in your stylesheet"
        say ""
      end
    end
  end
end
