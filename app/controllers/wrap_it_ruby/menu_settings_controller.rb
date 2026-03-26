# frozen_string_literal: true

module WrapItRuby
  class MenuSettingsController < ::ApplicationController
    def index
      @menu_items = menu_items_exist? ? ::MenuItem.roots.includes(children: :children) : []
    end

    def new
      @menu_item = ::MenuItem.new
    end

    def edit
      @menu_item = ::MenuItem.find(params[:id])
    end

    def create
      ::MenuItem.create!(menu_item_params)
      redirect_to wrap_it_ruby.menu_settings_path
    end

    def update
      item = ::MenuItem.find(params[:id])
      position = params.dig(:menu_item, :position) || params[:position]
      if position
        item.insert_at(position.to_i)
        head :no_content
      else
        item.update!(menu_item_params)
        redirect_to wrap_it_ruby.menu_settings_path
      end
    end

    def destroy
      item = ::MenuItem.find(params[:id])
      item.destroy!
      redirect_to wrap_it_ruby.menu_settings_path
    end

    def sort
      ordering = params.require(:ordering)

      ::MenuItem.transaction do
        ordering.each do |entry|
          item = ::MenuItem.find(entry[:id])
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
      params.permit(:label, :icon, :route, :url, :item_type, :parent_id)
    end

    def menu_items_exist?
      defined?(::MenuItem) && ::MenuItem.table_exists? && ::MenuItem.exists?
    rescue StandardError
      false
    end
  end
end
