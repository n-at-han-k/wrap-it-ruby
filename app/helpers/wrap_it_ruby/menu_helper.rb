require "yaml"

module WrapItRuby
  # Loads and queries the menu configuration from the host app's
  # config/menu.yml file.
  #
  # Can be used as a module (extend self) or included in controllers/helpers.
  #
  # The render_menu method requires the view context (ComponentHelper from
  # rails-active-ui must be available), so call it from views/layouts, not
  # as a bare module method.
  #
  module MenuHelper
    def menu_config = load_menu

    # Renders the sidebar menu using rails-active-ui component helpers.
    # Must be called from a view context where ComponentHelper is included.
    def render_menu
      Menu(attached: true) {
        WrapItRuby::MenuHelper.menu_config.each do |group|
          if group["items"]
            group["items"].each do |item|
              MenuItem(href: item["route"]) { text item["label"] }
            end
          else
            MenuItem(href: group["route"]) { text group["label"] }
          end
        end
      }
    end

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
