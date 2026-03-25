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

    # Renders the menu-settings, edit, and add modals.
    # Call this outside the Menu { } block so modals are not
    # nested inside the menu bar.
    def render_menu_modals
      # Settings modal — sortable tree + add button
      concat tag.div(id: 'menu-settings-modal', class: 'ui large modal') {
        safe_join([
                    tag.i(class: 'close icon'),
                    tag.div(class: 'header') { tag.i(class: 'bars icon') + ' Menu Settings' },
                    tag.div(class: 'scrolling content') {
                      tag.div(id: 'menu-tree-container') { sortable_menu_tree }
                    },
                    tag.div(class: 'actions') {
                      safe_join([
                                  tag.button(class: 'ui green button', onclick: 'menuSettingsShowAdd()') {
                                    tag.i(class: 'plus icon') + ' Add Item'
                                  }
                                ])
                    }
                  ])
      }

      # Edit modal — stacked on top of settings modal
      concat tag.div(id: 'menu-edit-modal', class: 'ui small modal') {
        safe_join([
                    tag.i(class: 'close icon'),
                    tag.div(class: 'header') { 'Edit Menu Item' },
                    tag.div(class: 'content') {
                      tag.form(class: 'ui form', id: 'menu-edit-form') {
                        safe_join([
                                    tag.input(type: 'hidden', name: 'id', id: 'menu-edit-id'),
                                    tag.div(class: 'two fields') {
                                      safe_join([
                                                  tag.div(class: 'field') {
                                                    tag.label {
                                                      'Label'
                                                    } + tag.input(type: 'text', name: 'label', id: 'menu-edit-label')
                                                  },
                                                  tag.div(class: 'field') {
                                                    tag.label {
                                                      'Icon'
                                                    } + tag.input(type: 'text', name: 'icon', id: 'menu-edit-icon',
                                                                  placeholder: 'e.g. server')
                                                  }
                                                ])
                                    },
                                    tag.div(class: 'two fields', id: 'menu-edit-proxy-fields') {
                                      safe_join([
                                                  tag.div(class: 'field') {
                                                    tag.label {
                                                      'Route'
                                                    } + tag.input(type: 'text', name: 'route', id: 'menu-edit-route',
                                                                  placeholder: '/path')
                                                  },
                                                  tag.div(class: 'field') {
                                                    tag.label {
                                                      'URL'
                                                    } + tag.input(type: 'text', name: 'url', id: 'menu-edit-url',
                                                                  placeholder: 'upstream.example.com')
                                                  }
                                                ])
                                    },
                                    tag.div(class: 'field') {
                                      tag.label { 'Type' } +
                                      tag.select(name: 'item_type', id: 'menu-edit-type', class: 'ui dropdown',
                                                 onchange: "menuSettingsToggleProxyFields('menu-edit')") {
                                        safe_join([
                                                    tag.option(value: 'group') { 'Group' },
                                                    tag.option(value: 'proxy') { 'Proxy' }
                                                  ])
                                      }
                                    }
                                  ])
                      }
                    },
                    tag.div(class: 'actions') {
                      safe_join([
                                  tag.button(class: 'ui red left floated button', onclick: 'menuSettingsDelete()') {
                                    tag.i(class: 'trash icon') + ' Delete'
                                  },
                                  tag.button(class: 'ui button', onclick: "$('#menu-edit-modal').modal('hide')") {
                                    'Cancel'
                                  },
                                  tag.button(class: 'ui green button', onclick: 'menuSettingsSave()') {
                                    tag.i(class: 'save icon') + ' Save'
                                  }
                                ])
                    }
                  ])
      }

      # Add modal — stacked on top of settings modal
      concat tag.div(id: 'menu-add-modal', class: 'ui small modal') {
        safe_join([
                    tag.i(class: 'close icon'),
                    tag.div(class: 'header') { 'Add Menu Item' },
                    tag.div(class: 'content') {
                      tag.form(class: 'ui form', id: 'menu-add-form') {
                        safe_join([
                                    tag.div(class: 'field') {
                                      tag.label { 'Type' } +
                                      tag.select(name: 'item_type', id: 'menu-add-type', class: 'ui dropdown',
                                                 onchange: "menuSettingsToggleProxyFields('menu-add')") {
                                        safe_join([
                                                    tag.option(value: 'group') { 'Group' },
                                                    tag.option(value: 'proxy') { 'Proxy' }
                                                  ])
                                      }
                                    },
                                    tag.div(class: 'two fields') {
                                      safe_join([
                                                  tag.div(class: 'field') {
                                                    tag.label {
                                                      'Label'
                                                    } + tag.input(type: 'text', name: 'label', id: 'menu-add-label')
                                                  },
                                                  tag.div(class: 'field') {
                                                    tag.label {
                                                      'Icon'
                                                    } + tag.input(type: 'text', name: 'icon', id: 'menu-add-icon',
                                                                  placeholder: 'e.g. server')
                                                  }
                                                ])
                                    },
                                    tag.div(class: 'two fields', id: 'menu-add-proxy-fields', style: 'display:none') {
                                      safe_join([
                                                  tag.div(class: 'field') {
                                                    tag.label {
                                                      'Route'
                                                    } + tag.input(type: 'text', name: 'route', id: 'menu-add-route',
                                                                  placeholder: '/path')
                                                  },
                                                  tag.div(class: 'field') {
                                                    tag.label {
                                                      'URL'
                                                    } + tag.input(type: 'text', name: 'url', id: 'menu-add-url',
                                                                  placeholder: 'upstream.example.com')
                                                  }
                                                ])
                                    },
                                    tag.div(class: 'field') {
                                      tag.label { 'Parent' } +
                                      tag.select(name: 'parent_id', id: 'menu-add-parent', class: 'ui dropdown') {
                                        safe_join([
                                                    tag.option(value: '') { 'Root (top level)' },
                                                    *menu_group_options
                                                  ])
                                      }
                                    }
                                  ])
                      }
                    },
                    tag.div(class: 'actions') {
                      safe_join([
                                  tag.button(class: 'ui button', onclick: "$('#menu-add-modal').modal('hide')") {
                                    'Cancel'
                                  },
                                  tag.button(class: 'ui green button', onclick: 'menuSettingsCreate()') {
                                    tag.i(class: 'plus icon') + ' Add'
                                  }
                                ])
                    }
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

    # Builds <option> tags for all group items (for parent dropdown in add modal).
    # Indents sub-groups with dashes to show hierarchy.
    def menu_group_options(items = nil, depth = 0)
      items ||= ::MenuItem.groups.where(parent_id: nil).order(:position).includes(children: :children)
      items.flat_map do |item|
        prefix = "\u00A0\u00A0" * depth + (depth > 0 ? "\u2514 " : '')
        opts = [tag.option(value: item.id) { "#{prefix}#{item.label}" }]
        sub_groups = item.children.select(&:group?)
        opts += menu_group_options(sub_groups, depth + 1) if sub_groups.any?
        opts
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
