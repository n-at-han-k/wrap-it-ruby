Menu(attached: true) {
  WrapItRuby::Menu.menu_config.each do |group|
    if group["items"]
      group["items"].each do |item|
        MenuItem(href: item["route"]) { text item["label"] }
      end
    else
      MenuItem(href: group["route"]) { text group["label"] }
    end
  end
}
