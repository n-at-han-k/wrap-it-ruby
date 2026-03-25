# frozen_string_literal: true

module WrapItRuby
  class MenuSettingsController < ::ApplicationController
    def index
      @menu_items = ::MenuItem.roots.includes(children: :children)
    end

    def create
      ::MenuItem.create!(menu_item_params)
      respond_with_tree_refresh
    end

    def update
      item = ::MenuItem.find(params[:id])
      item.update!(menu_item_params)
      respond_with_tree_refresh
    end

    def destroy
      item = ::MenuItem.find(params[:id])
      item.destroy!
      respond_with_tree_refresh
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

      respond_with_tree_refresh
    end

    private

    def menu_item_params
      params.permit(:label, :icon, :route, :url, :item_type, :parent_id)
    end

    def respond_with_tree_refresh
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            'menu-tree-container',
            partial: 'wrap_it_ruby/menu_settings/tree'
          )
        end
        format.html { head :no_content }
      end
    end
  end
end
