# Add Menu Item

Style('
  form:has(select[name="item_type"] option[value="group"]:checked) .field:has([name="route"]),
  form:has(select[name="item_type"] option[value="group"]:checked) .field:has([name="url"]) {
    display: none;
  }
')

Container {
  Header(size: :h1, icon: "plus") {
    text "Add Menu Item"
  }

  Segment {
    Form(url: create_menu_setting_path, method: :post) {
      Grid(columns: 2) {
        Column {
          Select(name: "item_type", label_text: "Type", options: [["Group", "group"], ["Proxy", "proxy"]])
        }
        Column {
          Select(name: "parent_id", label_text: "Parent", options: [["Root (top level)", ""]] + menu_group_options_for_select)
        }
      }

      Grid(columns: 2) {
        Column {
          TextField(name: "label", label: "Label", placeholder: "Menu item label")
        }
        Column {
          TextField(name: "icon", label: "Icon", placeholder: "e.g. server")
        }
      }

      Grid(columns: 2) {
        Column {
          TextField(name: "route", label: "Route", placeholder: "/path")
        }
        Column {
          TextField(name: "url", label: "URL", placeholder: "upstream.example.com")
        }
      }

      Divider(hidden: true)

      Button(color: "green", type: "submit") {
        Icon(name: "plus")
        text " Add"
      }
      Button(href: menu_settings_path) { text "Cancel" }
    }
  }
}
