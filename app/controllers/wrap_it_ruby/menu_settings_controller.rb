# frozen_string_literal: true

module WrapItRuby
  class MenuSettingsController < ::ApplicationController
    def index
      @menu_items = menu_item_model.roots.includes(children: :children)
    end

    def sort
      item = menu_item_model.find(params[:id])

      menu_item_model.transaction do
        new_parent_id = params[:parent_id].presence
        if item.parent_id.to_s != new_parent_id.to_s
          item.remove_from_list
          item.update!(parent_id: new_parent_id)
        end

        item.insert_at(params[:position].to_i)
      end

      respond_to do |format|
        format.turbo_stream
        format.html { head :no_content }
      end
    end

    private

    def menu_item_model
      WrapItRuby.menu_item_model or
        raise 'WrapItRuby.menu_item_class is not configured'
    end
  end
end
