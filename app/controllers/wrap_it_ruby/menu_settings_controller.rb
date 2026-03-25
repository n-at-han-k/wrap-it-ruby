# frozen_string_literal: true

module WrapItRuby
  class MenuSettingsController < ::ApplicationController
    def index
      @menu_items = ::MenuItem.roots.includes(children: :children)
    end

    def update
      item = ::MenuItem.find(params[:id])
      item.update!(params.permit(:label, :icon, :route, :url, :item_type))
      head :no_content
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

      respond_to do |format|
        format.turbo_stream
        format.html { head :no_content }
      end
    end
  end
end
