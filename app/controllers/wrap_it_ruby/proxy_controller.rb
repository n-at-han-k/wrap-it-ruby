# frozen_string_literal: true

module WrapItRuby
  class ProxyController < ApplicationController
    before_action :authenticate_user!

    def show
      get_menu_item.then do |menu_item|
        target_path   = request.path.delete_prefix(menu_item["route"])
        target_domain = menu_item["url"]

        target_url  = "#{target_domain}/#{target_path}"
        @iframe_src = "/_proxy/#{target_url}"
      end
    end

    private

      def get_menu_item
        path = request.path
        all_proxy_menu_items.find { |item| path.start_with?(item["route"]) }
      end
  end
end
