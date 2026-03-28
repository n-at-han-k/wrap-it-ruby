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
            Icon(name: "arrows alternate", class: "drag-handle")
            text item.icon if item.icon
            text " "
            text item.label
            Link(href: edit_menu_setting_path(item), class: "edit-link") { Icon(name: "pencil") }
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
                    Icon(name: "arrows alternate", class: "drag-handle")
                    text child.icon if child.icon
                    text " "
                    text child.label
                    Link(href: edit_menu_setting_path(child), class: "edit-link") { Icon(name: "pencil") }
                  }
                  Wrapper(html_class: "ui segments",
                    data: {
                      controller: "wrap-it-ruby--sortable",
                      sortable_animation_value: "150",
                      sortable_resource_name_value: "menu_item"
                    }) {
                    child.children.each do |grandchild|
                      Segment(attached: true, data: { sortable_update_url: update_menu_setting_path(grandchild) }) {
                        Icon(name: "arrows alternate", class: "drag-handle")
                        text grandchild.icon if grandchild.icon
                        text " "
                        text grandchild.label
                        Link(href: edit_menu_setting_path(grandchild), class: "edit-link") { Icon(name: "pencil") }
                      }
                    end
                  }
                }
              else
                Segment(attached: true, data: { sortable_update_url: update_menu_setting_path(child) }) {
                  Icon(name: "arrows alternate", class: "drag-handle")
                  text child.icon if child.icon
                  text " "
                  text child.label
                  Link(href: edit_menu_setting_path(child), class: "edit-link") { Icon(name: "pencil") }
                }
              end
            end
          }
        }
      else
        Segment(attached: true, data: { sortable_update_url: update_menu_setting_path(item) }) {
          Icon(name: "arrows alternate", class: "drag-handle")
          text item.icon if item.icon
          text " "
          text item.label
          Link(href: edit_menu_setting_path(item), class: "edit-link") { Icon(name: "pencil") }
        }
      end
    end
  }

  Divider(hidden: true)

  Button(color: "green", href: new_menu_setting_path) {
    Icon(name: "plus")
    text " Add Item"
  }
  Button(href: export_menu_settings_path) {
    text "export menu"
  }
}
