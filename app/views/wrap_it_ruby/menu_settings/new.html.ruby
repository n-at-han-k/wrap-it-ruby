# Add Menu Item

Style('
  form:has(select[name="menu_item[item_type]"] option[value="group"]:checked) .field:has([name="menu_item[route]"]),
  form:has(select[name="menu_item[item_type]"] option[value="external"]:checked) .field:has([name="menu_item[route]"]),
  form:has(select[name="menu_item[item_type]"] option[value="group"]:checked) .field:has([name="menu_item[url]"]) {
    display: none;
  }
')

Container {
  Header(size: :h1, icon: "plus") {
    text "Add Menu Item"
  }

  Segment {
    Form(model: @menu_item, url: create_menu_setting_path, method: :post) {
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
        Icon(name: "plus")
        text " Add"
      }
      Button(href: menu_settings_path) { text "Cancel" }
    }
  }
}
