# frozen_string_literal: true

module WrapItRuby
  class MenuSettingsController < ::ApplicationController
    def index
      @menu_items = menu_items_exist? ? MenuItem.roots.includes(children: :children) : []
    end

    def new
      @menu_item = MenuItem.new
    end

    def edit
      @menu_item = MenuItem.find(params[:id])
    end

    def export
      send_data(
        exported_menu_yaml,
        type: "text/yaml; charset=utf-8",
        disposition: "inline",
        filename: "menu.yaml"
      )
    end

    def create
      MenuItem.create!(menu_item_params)
      redirect_to wrap_it_ruby.menu_settings_path
    end

    def update
      item = MenuItem.find(params[:id])
      position = params.dig(:menu_item, :position) || params[:position]
      if position
        item.move_to(params[:parent_id].presence, position.to_i)
        head :no_content
      else
        item.update!(menu_item_params)
        redirect_to wrap_it_ruby.menu_settings_path
      end
    end

    def destroy
      item = MenuItem.find(params[:id])
      item.destroy!
      redirect_to wrap_it_ruby.menu_settings_path
    end

    def sort
      ordering = params.require(:ordering)

      MenuItem.transaction do
        ordering.each do |entry|
          item = MenuItem.find(entry[:id])
          new_parent_id = entry[:parent_id].presence

          if item.parent_id.to_s != new_parent_id.to_s
            item.remove_from_list
            item.update!(parent_id: new_parent_id)
          end

          item.insert_at(entry[:position].to_i)
        end
      end

      redirect_to wrap_it_ruby.menu_settings_path
    end

    private

    def menu_item_params
      params.require(:menu_item).permit(:label, :icon, :route, :url, :item_type, :parent_id)
    end

    def menu_items_exist?
      defined?(MenuItem) && MenuItem.table_exists? && MenuItem.exists?
    rescue StandardError
      false
    end

    def exported_menu_yaml
      return File.read(menu_file_path) if menu_file_path.exist? && !menu_items_exist?

      menu_items = menu_items_exist? ? MenuItem.roots.includes(children: :children) : []
      menu_items.map { |item| export_item(item) }.to_yaml
    end

    def export_item(item)
      payload = { "label" => item.label }

      if item.group?
        payload["icon"] = item.icon if item.icon.present?
        payload["items"] = item.children.order(:position).map { |child| export_item(child) }
      else
        payload["route"] = item.route if item.route.present?
        payload["url"] = item.url if item.url.present?
        payload["icon"] = item.icon if item.icon.present?
        payload["type"] = item.item_type
      end

      payload
    end

    def menu_file_path
      Rails.root.join("config/menu.yml")
    end
  end
end
