# frozen_string_literal: true

require "async/http/client"
require "async/http/endpoint"

module WrapItRuby
  module Middleware
    # Protocol::HTTP middleware that intercepts WebSocket upgrade requests
    # BEFORE the Rack adapter, proxying them directly at the HTTP protocol
    # level. This preserves the Upgrade/Connection headers that Rack strips.
    #
    # Must be inserted as Falcon middleware, not as Rack middleware.
    # For non-WebSocket requests, passes through to the Rack app.
    #
    class WebSocketProxy < Protocol::HTTP::Middleware
      PROXY_PATTERN = %r{\A/_proxy/(?<host>[^/]+)(?<path>/.*)?\z}

      HOP_HEADERS = %w[
        connection keep-alive proxy-authenticate proxy-authorization
        te trailers transfer-encoding upgrade
      ].freeze

      def initialize(app)
        super(app)
        @clients = {}
      end

      def call(request)
        if websocket?(request) && (match = PROXY_PATTERN.match(request.path))
          host = match[:host].delete_suffix(".")
          proxy_websocket(request, host)
        else
          super(request)
        end
      end

      private

      def websocket?(request)
        # HTTP/2: protocol pseudo-header
        if Array(request.protocol).any? { |p| p.casecmp?("websocket") }
          return true
        end
        # HTTP/1.1: Upgrade header
        if upgrade = request.headers["upgrade"]
          return Array(upgrade).any? { |u| u.casecmp?("websocket") }
        end
        false
      end

      def proxy_websocket(request, host)
        # Strip /_proxy/{host} prefix from the path
        match = PROXY_PATTERN.match(request.path)
        request.path = match[:path] || "/"

        # Rewrite authority/host to upstream — write_request adds host
        # from authority automatically, so just delete it from headers.
        request.authority = host
        request.headers.delete("host")

        # Set protocol as string (not array) for write_upgrade_body,
        # and remove upgrade/connection headers to avoid duplicates.
        request.protocol = "websocket"
        request.headers.delete("upgrade")
        request.headers.delete("connection")

        # Rewrite origin
        if request.headers["origin"]
          request.headers.delete("origin")
          request.headers.add("origin", "https://#{host}")
        end

        client = client_for(host)
        client.call(request)
      rescue => error
        $stderr.puts "[ws-proxy] upstream error: #{error.class}: #{error.message}"
        Protocol::HTTP::Response[502, {}, ["WebSocket proxy error: #{error.message}"]]
      end

      def client_for(host)
        # Force HTTP/1.1 — upstream (Traefik/code-server) returns 405
        # for HTTP/2 WebSocket CONNECT but accepts HTTP/1.1 Upgrade.
        @clients[host] ||= Async::HTTP::Client.new(
          Async::HTTP::Endpoint.parse("https://#{host}",
            alpn_protocols: Async::HTTP::Protocol::HTTP11.names
          ),
          retries: 0
        )
      end
    end
  end
end
