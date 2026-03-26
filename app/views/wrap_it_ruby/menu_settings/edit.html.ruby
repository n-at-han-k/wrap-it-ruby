# Edit Menu Item

Style('
  form:has(select[name="menu_item[item_type]"] option[value="group"]:checked) .field:has([name="menu_item[route]"]),
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
          Select(:item_type, [["Group", "group"], ["Link", "link"]], hint: "Group contains children, Link opens a website")
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
          TextField(:route, placeholder: "/path", hint: "The URL to visit after clicking, e.g. #{request.base_url}/git")
        }
        Column {
          TextField(:url, placeholder: "upstream.example.com", hint: "The web address for this website, e.g. github.com")
        }
      }

      Divider(hidden: true)

      Button(color: "green", type: "submit") {
        Icon(name: "save")
        text " Save"
      }
      Button(href: menu_settings_path) { text "Cancel" }
    }
  }

  Divider(hidden: true)

  ButtonTo(url: destroy_menu_setting_path(@menu_item), method: :delete, color: "red", confirm: "Delete this item and all its children?") {
    Icon(name: "trash")
    text " Delete"
  }
}
