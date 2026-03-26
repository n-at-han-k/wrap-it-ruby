Container {
  Header(size: :h1, icon: "bars") {
    text "Menu Settings"
  }

  Wrapper(id: "menu-sortable",
    html_class: "ui segments",
    data: {
      controller: "wrap-it-ruby--sortable",
      sortable_animation_value: "150",
      sortable_resource_name_value: "menu_item"
    }) {
    @menu_items.each do |item|
      if item.group?
        Accordion(attached: true, data: { sortable_update_url: update_menu_setting_path(item) }) { |a|
          a.title {
            Icon(name: "braille", class: "drag-handle")
            Icon(name: item.icon) if item.icon
            text item.label
          }
          Wrapper(html_class: "ui segments",
            data: {
              controller: "wrap-it-ruby--sortable",
              sortable_animation_value: "150",
              sortable_resource_name_value: "menu_item"
            }) {
            item.children.each do |child|
              if child.group?
                Accordion(attached: true, data: { sortable_update_url: update_menu_setting_path(child) }) { |a2|
              a2.title {
                Icon(name: "braille", class: "drag-handle")
                Icon(name: child.icon) if child.icon
                text child.label
              }
                  Wrapper(html_class: "ui segments",
                    data: {
                      controller: "wrap-it-ruby--sortable",
                      sortable_animation_value: "150",
                      sortable_resource_name_value: "menu_item"
                    }) {
                    child.children.each do |grandchild|
                      Segment(attached: true, data: { sortable_update_url: update_menu_setting_path(grandchild) }) {
                        Icon(name: "braille", class: "drag-handle")
                        Icon(name: grandchild.icon) if grandchild.icon
                        text grandchild.label
                      }
                    end
                  }
                }
              else
                Segment(attached: true, data: { sortable_update_url: update_menu_setting_path(child) }) {
                  Icon(name: "braille", class: "drag-handle")
                  Icon(name: child.icon) if child.icon
                  text child.label
                }
              end
            end
          }
        }
      else
        Segment(attached: true, data: { sortable_update_url: update_menu_setting_path(item) }) {
          Icon(name: "braille", class: "drag-handle")
          Icon(name: item.icon) if item.icon
          text item.label
        }
      end
    end
  }

  Divider(hidden: true)

  Button(color: "green", href: new_menu_setting_path) {
    Icon(name: "plus")
    text " Add Item"
  }
}
