# frozen_string_literal: true

require 'async/http/client'
require 'async/http/endpoint'

module WrapItRuby
  module Middleware
    # Protocol::HTTP middleware that intercepts WebSocket upgrade requests
    # BEFORE the Rack adapter, proxying them directly at the HTTP protocol
    # level. This preserves the Upgrade/Connection headers that Rack strips.
    #
    # Header strategy (whitelist → modify → add):
    #   1. Whitelist — only forward known-safe headers to upstream
    #   2. Modify   — rewrite origin to match upstream host
    #   3. Add      — protocol and authority are set for the HTTP client
    #
    # Must be inserted as Falcon middleware, not as Rack middleware.
    # For non-WebSocket requests, passes through to the Rack app.
    #
    class WebSocketProxy < Protocol::HTTP::Middleware
      PROXY_PATTERN = %r{\A/_proxy/(?<host>[^/]+)(?<path>/.*)?\z}

      # Headers whitelisted for WebSocket upgrade forwarding.
      # Notably excludes: host (set via authority), upgrade/connection
      # (set via protocol field), and all browser metadata headers.
      WS_REQUEST_WHITELIST = %w[
        accept-language
        authorization
        cache-control
        cookie
        origin
        pragma
        sec-websocket-extensions
        sec-websocket-key
        sec-websocket-protocol
        sec-websocket-version
        user-agent
      ].to_set.freeze

      def initialize(app)
        super(app)
        @clients = {}
      end

      def call(request)
        if websocket?(request) && (match = PROXY_PATTERN.match(request.path))
          host = match[:host].delete_suffix('.')
          proxy_websocket(request, host, match)
        else
          super(request)
        end
      end

      private

      def websocket?(request)
        # HTTP/2: protocol pseudo-header
        return true if Array(request.protocol).any? { |p| p.casecmp?('websocket') }
        # HTTP/1.1: Upgrade header
        if upgrade = request.headers['upgrade']
          return Array(upgrade).any? { |u| u.casecmp?('websocket') }
        end

        false
      end

      def proxy_websocket(request, host, match)
        # Strip /_proxy/{host} prefix from the path
        request.path = match[:path] || '/'

        # Build clean headers: whitelist → modify → add
        clean = Protocol::HTTP::Headers.new

        # 1. Whitelist
        request.headers.each do |name, value|
          next unless WS_REQUEST_WHITELIST.include?(name)

          clean.add(name, value)
        end

        # 2. Modify: rewrite origin to match upstream
        if clean['origin']
          clean.delete('origin')
          clean.add('origin', "https://#{host}")
        end

        # 3. Add: protocol and authority for the HTTP client.
        #    - host is written by write_request from authority (not headers)
        #    - upgrade/connection are written by write_upgrade_body from protocol
        request.headers = clean
        request.authority = host
        request.protocol = 'websocket'

        client = client_for(host)
        client.call(request)
      rescue StandardError => e
        warn "[ws-proxy] upstream error: #{e.class}: #{e.message}"
        Protocol::HTTP::Response[502, {}, ["WebSocket proxy error: #{e.message}"]]
      end

      def client_for(host)
        # Force HTTP/1.1 — upstream (Traefik) doesn't support WS over
        # HTTP/2 CONNECT, only HTTP/1.1 Upgrade.
        @clients[host] ||= Async::HTTP::Client.new(
          Async::HTTP::Endpoint.parse("https://#{host}",
                                      alpn_protocols: Async::HTTP::Protocol::HTTP11.names),
          retries: 0
        )
      end
    end
  end
end
