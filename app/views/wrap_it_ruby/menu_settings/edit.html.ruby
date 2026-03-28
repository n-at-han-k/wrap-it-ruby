# Edit Menu Item

Style('
  form:has(select[name="menu_item[item_type]"] option[value="group"]:checked) .field:has([name="menu_item[route]"]),
  form:has(select[name="menu_item[item_type]"] option[value="external"]:checked) .field:has([name="menu_item[route]"]),
  form:has(select[name="menu_item[item_type]"] option[value="group"]:checked) .field:has([name="menu_item[url]"]) {
    display: none;
  }
')

Container {
  Header(size: :h1, icon: "pencil") {
    text "Edit Menu Item"
  }

  Segment {
    Form(model: @menu_item, url: update_menu_setting_path(@menu_item), method: :patch) {
      Grid(columns: 2) {
        Column {
          Select(:item_type, [["Group", "group"], ["Internal", "internal"], ["External", "external"]], hint: "Group contains children, Internal opens in app, External opens a new tab")
        }
        Column {
          Select(:parent_id, [["No group (top level)", ""]] + menu_group_options_for_select, hint: "Which group this item belongs to")
        }
      }

      Grid(columns: 2) {
        Column {
          TextField(:label, placeholder: "Menu item label", hint: "Display name in the menu")
        }
        Column {
          EmojiField(:icon, hint: "Emoji shown next to the label")
        }
      }

      Grid(columns: 2) {
        Column {
          TextField(:route, placeholder: "github", hint: "Short name (lowercase letters and dashes only), e.g. github")
        }
        Column {
          TextField(:url, placeholder: "https://github.com/path", hint: "Full URL of the website to proxy, e.g. https://github.com")
        }
      }

      Divider(hidden: true)

      Button(color: "green", type: "submit") {
        Icon(name: "save")
        text " Save"
      }
      Button(href: menu_settings_path) { text "Cancel" }
      Button(href: export_menu_settings_path) { text "export menu" }
    }
  }

  Divider(hidden: true)

  ButtonTo(url: destroy_menu_setting_path(@menu_item), method: :delete, color: "red", confirm: "Delete this item and all its children?") {
    Icon(name: "trash")
    text " Delete"
  }
}
