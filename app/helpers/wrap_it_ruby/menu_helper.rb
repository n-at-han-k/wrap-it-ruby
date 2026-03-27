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

    # Renders the menu entries using rails-active-ui component helpers.
    # Must be called from inside a Menu { } block in the layout.
    #
    # Supports arbitrary nesting depth:
    #   - Top-level entries with "items" render as Fomantic-UI simple
    #     dropdown menu items (hover to open).
    #   - Nested entries with "items" render as flyout sub-dropdowns
    #     (dropdown icon + nested .menu inside an .item).
    #   - Leaf entries render as plain linked menu items.
    def render_menu
      WrapItRuby::MenuHelper.menu_config.each do |entry|
        render_menu_entry(entry, top_level: true)
      end
    end


    def all_menu_items
      flatten_items(menu_config)
    end

    def all_proxy_menu_items
      all_menu_items.select { |item| item['type'] == 'proxy' }
    end

    # Returns browser paths (with leading /) for all proxy menu items.
    # Used by the route constraint to decide which requests hit ProxyController.
    def proxy_paths
      all_proxy_menu_items.map { |item| "/#{item['route']}" }
    end

    # Build the full href for a menu entry.
    #
    # The route is a bare slug (e.g. "github") and url may contain a path
    # (e.g. "github.com/nathank/repo"). The href combines them:
    #   route "github" + url "github.com/nathank/repo" → "/github/nathank/repo"
    #   route "ebay"   + url "ebay.co.uk"              → "/ebay"
    #   route "about"  + url nil                        → "/about"
    def menu_href(entry)
      route = entry['route']
      return nil if route.blank?

      url = entry['url']
      if url.present?
        uri_path = URI.parse("https://#{url}").path.to_s
        "/#{route}#{uri_path}"
      else
        "/#{route}"
      end
    rescue URI::InvalidURIError
      "/#{route}"
    end

    # Check whether a request path matches a proxy menu item's route.
    # Matches on exact first segment to prevent "git" matching "/github/...".
    def proxy_route_match?(request_path, route)
      request_path.match?(%r{\A/#{Regexp.escape(route)}(/|\z)})
    end

    # Returns true if the request path matches any proxy menu item route.
    # Used by the route constraint in config/routes.rb.
    def proxy_route?(request_path)
      all_proxy_menu_items.any? { |item| proxy_route_match?(request_path, item['route']) }
    end

    def reset_menu_cache!; end

    extend self

    private

    def render_menu_entry(entry, top_level: false)
      if entry['items']
        if top_level
          MenuItem(dropdown: true) do
            text entry['icon'] if entry['icon']
            text " "
            text entry['label']
            Icon(name: "dropdown")
            SubMenu do
              entry['items'].each { |child| render_menu_entry(child) }
            end
          end
        else
          MenuItem do
            Icon(name: "dropdown")
            text entry['icon'] if entry['icon']
            text " "
            text entry['label']
            SubMenu do
              entry['items'].each { |child| render_menu_entry(child) }
            end
          end
        end
      else
        MenuItem(href: menu_href(entry)) {
          text entry['icon'] if entry['icon']
          text " "
          text entry['label']
        }
      end
    end

    # Renders a sortable-tree container.
    # Pass an array of MenuItem records (roots with children eager-loaded).
    # The Stimulus controller reads the JSON and initializes sortable-tree.
    def sortable_menu_tree
      unless database_menu_available?
        return tag.div { "No menu items. Configure MenuItem in your app or use config/menu.yml" }
      end
      items = WrapItRuby::MenuItem.roots.includes(children: :children)
      nodes_json = menu_items_to_nodes(items).to_json
      sort_url = wrap_it_ruby.sort_menu_setting_path(id: 'bulk')
      edit_url_template = wrap_it_ruby.edit_menu_setting_path(id: ':id')

      tag.div(
        data: {
          controller: 'wrap-it-ruby--sortable-tree',
          "wrap-it-ruby--sortable-tree-nodes-value": nodes_json,
          "wrap-it-ruby--sortable-tree-sort-url-value": sort_url,
          "wrap-it-ruby--sortable-tree-edit-url-template-value": edit_url_template,
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

    # Returns [label, value] pairs for all group items, suitable for
    # f.select in the new/edit forms.  Indents sub-groups to show hierarchy.
    def menu_group_options_for_select(items = nil, depth = 0)
      items ||= WrapItRuby::MenuItem.groups.where(parent_id: nil).order(:position).includes(children: :children)
      items.flat_map do |item|
        prefix = "\u00A0\u00A0" * depth + (depth > 0 ? "\u2514 " : '')
        opts = [ [ "#{prefix}#{item.label}", item.id ] ]
        sub_groups = item.children.select(&:group?)
        opts += menu_group_options_for_select(sub_groups, depth + 1) if sub_groups.any?
        opts
      end
    end

    def flatten_items(items)
      items.flat_map { |item| [ item, *flatten_items(item.fetch('items', [])) ] }
    end

    def menu_file
      Rails.root.join('config/menu.yml')
    end

    def load_menu
      if database_menu_available?
        load_menu_from_database
      else
        YAML.load_file(menu_file)
      end
    end

    def database_menu_available?
      defined?(WrapItRuby::MenuItem) && WrapItRuby::MenuItem.table_exists? && WrapItRuby::MenuItem.exists?
    rescue StandardError
      false
    end

    def load_menu_from_database
      WrapItRuby::MenuItem.roots.includes(children: :children).map { |item| item_to_hash(item) }
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
