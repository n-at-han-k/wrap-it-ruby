require 'yaml'

module WrapItRuby
  # Loads and queries the menu configuration from the host app's
  # config/menu.yml file, or from the database when menu_item_class
  # is configured.
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
    #
    # Supports arbitrary nesting depth:
    #   - Top-level entries with "items" render as Fomantic-UI simple
    #     dropdown menu items (hover to open).
    #   - Nested entries with "items" render as flyout sub-dropdowns
    #     (dropdown icon + nested .menu inside an .item).
    #   - Leaf entries render as plain linked menu items.
    def render_menu
      Menu(attached: true) do
        WrapItRuby::MenuHelper.menu_config.each do |entry|
          render_menu_entry(entry, top_level: true)
        end
        if database_menu_available?
          MenuItem(position: 'right') do
            concat tag.button(class: 'ui mini icon button', onclick: "$('#menu-settings-modal').modal('show')") {
              tag.i(class: 'pencil icon')
            }
          end
        end
      end

      return unless database_menu_available?

      concat tag.div(id: 'menu-settings-modal', class: 'ui large modal') {
        safe_join([
                    tag.i(class: 'close icon'),
                    tag.div(class: 'header') { tag.i(class: 'bars icon') + ' Menu Settings' },
                    tag.div(class: 'scrolling content') { sortable_menu_tree }
                  ])
      }
    end

    def all_menu_items
      flatten_items(menu_config)
    end

    def all_proxy_menu_items
      all_menu_items.select { |item| item['type'] == 'proxy' }
    end

    def proxy_paths
      all_menu_items
        .select { |item| item['type'] == 'proxy' }
        .map    { |item| item['route'] }
    end

    def reset_menu_cache!
      @menu_config = nil
    end

    extend self

    private

    def render_menu_entry(entry, top_level: false)
      if entry['items']
        if top_level
          MenuItem(dropdown: true, icon: entry['icon']) do
            text entry['label']
            concat tag.i(class: 'dropdown icon')
            SubMenu do
              entry['items'].each { |child| render_menu_entry(child) }
            end
          end
        else
          MenuItem do
            concat tag.i(class: 'dropdown icon')
            text entry['label']
            SubMenu do
              entry['items'].each { |child| render_menu_entry(child) }
            end
          end
        end
      else
        MenuItem(href: entry['route'], icon: entry['icon']) { text entry['label'] }
      end
    end

    # Renders a sortable-tree container.
    # Pass an array of MenuItem records (roots with children eager-loaded).
    # The Stimulus controller reads the JSON and initializes sortable-tree.
    def sortable_menu_tree
      items = ::MenuItem.roots.includes(children: :children)
      nodes_json = menu_items_to_nodes(items).to_json
      sort_url = wrap_it_ruby.sort_menu_setting_path(id: 'bulk')

      tag.div(
        data: {
          controller: 'wrap-it-ruby--sortable-tree',
          "wrap-it-ruby--sortable-tree-nodes-value": nodes_json,
          "wrap-it-ruby--sortable-tree-sort-url-value": sort_url,
          "wrap-it-ruby--sortable-tree-lock-root-value": false,
          "wrap-it-ruby--sortable-tree-collapse-level-value": 3
        }
      )
    end

    # Converts MenuItem records to the sortable-tree nodes format:
    #   [{ data: { id:, title:, icon:, route:, url: }, nodes: [...] }]
    def menu_items_to_nodes(items)
      items.map do |item|
        {
          data: {
            id: item.id,
            title: item.label,
            icon: item.icon,
            route: item.route,
            url: item.url,
            item_type: item.item_type
          },
          nodes: item.children.any? ? menu_items_to_nodes(item.children) : []
        }
      end
    end

    def flatten_items(items)
      items.flat_map { |item| [item, *flatten_items(item.fetch('items', []))] }
    end

    def menu_file
      Rails.root.join('config/menu.yml')
    end

    def load_menu
      @menu_config ||= if database_menu_available?
                         load_menu_from_database
                       else
                         YAML.load_file(menu_file)
                       end
    end

    def database_menu_available?
      defined?(::MenuItem) && ::MenuItem.table_exists? && ::MenuItem.exists?
    rescue StandardError
      false
    end

    def load_menu_from_database
      ::MenuItem.roots.includes(children: :children).map { |item| item_to_hash(item) }
    end

    def item_to_hash(item)
      hash = { 'label' => item.label, 'icon' => item.icon }

      if item.children.any?
        hash['items'] = item.children.map { |child| item_to_hash(child) }
      else
        hash['route'] = item.route
        hash['url']   = item.url
        hash['type']  = item.item_type
      end

      hash
    end
  end
end
