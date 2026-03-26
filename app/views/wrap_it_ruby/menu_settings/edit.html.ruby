# Edit Menu Item

Container {
  Header(size: :h1, icon: "pencil") {
    text "Edit Menu Item"
  }

  Segment {
    Form(url: update_menu_setting_path(@menu_item), method: :patch) {
      Grid(columns: 2) {
        Column {
          TextField(name: "label", label: "Label", value: @menu_item.label)
        }
        Column {
          TextField(name: "icon", label: "Icon", value: @menu_item.icon, placeholder: "e.g. server")
        }
      }

      Grid(columns: 2) {
        Column {
          TextField(name: "route", label: "Route", value: @menu_item.route, placeholder: "/path")
        }
        Column {
          TextField(name: "url", label: "URL", value: @menu_item.url, placeholder: "upstream.example.com")
        }
      }

      Select(name: "item_type", label_text: "Type", options: [["Group", "group"], ["Proxy", "proxy"]], selected: @menu_item.item_type)

      Divider(hidden: true)

      Button(color: "green", type: "submit") {
        Icon(name: "save")
        text " Save"
      }
      Button(href: menu_settings_path) { text "Cancel" }
    }
  }

  Divider(hidden: true)

  text button_to(destroy_menu_setting_path(@menu_item),
                 method: :delete,
                 form: { data: { turbo_confirm: "Delete this item and all its children?" } },
                 class: "ui red button") {
    capture {
      Icon(name: "trash")
      text " Delete"
    }
  }
}
