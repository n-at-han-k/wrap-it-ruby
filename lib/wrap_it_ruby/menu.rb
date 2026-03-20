# frozen_string_literal: true

require "yaml"

module WrapItRuby
  # Loads and queries the menu configuration from the host app's
  # config/menu.yml file.
  #
  # Can be used as a module (extend self) or included in controllers/helpers.
  #
  module Menu
    def menu_config = load_menu

    def all_menu_items
      menu_config.flat_map { |item| [item, *item.fetch("items", [])] }
    end

    def all_proxy_menu_items
      all_menu_items.select { |item| item["type"] == "proxy" }
    end

    def proxy_paths
      all_menu_items
        .select { |item| item["type"] == "proxy" }
        .map    { |item| item["route"] }
    end

    extend self

    private

      def menu_file
        Rails.root.join("config/menu.yml")
      end

      def load_menu
        @menu_config ||= YAML.load_file(menu_file)
      end
  end
end
