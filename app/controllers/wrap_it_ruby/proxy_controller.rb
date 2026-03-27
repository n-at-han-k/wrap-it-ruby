# frozen_string_literal: true

module WrapItRuby
  class ProxyController < ::ApplicationController
    include WrapItRuby::MenuHelper
    include WrapItRuby::IframeHelper

    def show
      get_menu_item.then do |menu_item|
        remaining     = request.path.delete_prefix("/#{menu_item['route']}")
        upstream_host = extract_upstream_host(menu_item["url"])
        target_url    = "#{upstream_host}#{remaining}"
        proxy_host    = ENV["WRAP_IT_PROXY_HOST"]
        @iframe_src   = proxy_host ? "//#{proxy_host}/_proxy/#{target_url}" : "/_proxy/#{target_url}"
      end
    end

    private

      def get_menu_item
        path = request.path
        all_proxy_menu_items.find { |item| proxy_route_match?(path, item["route"]) }
      end

      # Extract just the host from a stored url (protocol already stripped).
      # e.g. "github.com/nathank/repo" → "github.com"
      def extract_upstream_host(url)
        URI.parse("https://#{url}").host
      rescue URI::InvalidURIError
        url.to_s.split("/").first
      end
  end
end
