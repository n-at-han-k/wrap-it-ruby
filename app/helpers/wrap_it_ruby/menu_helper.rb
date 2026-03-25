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

      items = ::MenuItem.roots.includes(children: :children)

      accordion_content = tag.div(class: 'ui styled fluid tree accordion', data: { controller: 'fui-accordion' }) do
        safe_join(items.map { |group| render_accordion_group(group) })
      end

      concat tag.div(id: 'menu-settings-modal', class: 'ui large modal') {
        safe_join([
                    tag.i(class: 'close icon'),
                    tag.div(class: 'header') { tag.i(class: 'bars icon') + ' Menu Settings' },
                    tag.div(class: 'scrolling content') { accordion_content }
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

    # Renders one accordion group: a .title + .content pair.
    # If children are groups themselves, nests another accordion inside.
    def render_accordion_group(item)
      title = tag.div(class: 'active title') do
        icon = item.icon.present? ? tag.i(class: "#{item.icon} icon") : ''.html_safe
        tag.i(class: 'dropdown icon') + icon + ' ' + item.label
      end

      content = tag.div(class: 'active content') do
        if item.children.any?
          # Check if any children are groups (have their own children)
          has_sub_groups = item.children.any? { |c| c.children.any? }

          if has_sub_groups
            # Nested accordion for sub-groups
            tag.div(class: 'accordion') do
              safe_join(item.children.map do |child|
                if child.children.any?
                  render_accordion_group(child)
                else
                  render_accordion_leaf(child)
                end
              end)
            end
          else
            # All children are leaves — render as form fields
            safe_join(item.children.map { |child| render_accordion_leaf(child) })
          end
        end
      end

      safe_join([title, content])
    end

    # Renders a leaf menu item as an editable form row.
    def render_accordion_leaf(item)
      wrap_it_ruby.sort_menu_setting_path(item)
      update_url = wrap_it_ruby.update_menu_setting_path(item)

      tag.div(class: 'ui small form', style: 'margin-bottom:0.5em;') do
        tag.div(class: 'fields', style: 'margin-bottom:0;align-items:center;') do
          safe_join([
                      tag.div(class: 'one wide field') do
                        tag.i(class: 'grip vertical icon', style: 'cursor:grab;color:#999;margin-top:0.5em;')
                      end,
                      tag.div(class: 'two wide field') do
                        tag.input(type: 'text', name: 'icon', value: item.icon, placeholder: 'icon',
                                  data: { url: update_url })
                      end,
                      tag.div(class: 'four wide field') do
                        tag.input(type: 'text', name: 'label', value: item.label, placeholder: 'Label',
                                  data: { url: update_url })
                      end,
                      tag.div(class: 'four wide field') do
                        tag.input(type: 'text', name: 'route', value: item.route, placeholder: '/route',
                                  data: { url: update_url })
                      end,
                      tag.div(class: 'four wide field') do
                        tag.input(type: 'text', name: 'url', value: item.url, placeholder: 'upstream url',
                                  data: { url: update_url })
                      end,
                      tag.div(class: 'one wide field') do
                        tag.i(class: 'trash icon', style: 'cursor:pointer;color:#db2828;margin-top:0.5em;')
                      end
                    ])
        end
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
