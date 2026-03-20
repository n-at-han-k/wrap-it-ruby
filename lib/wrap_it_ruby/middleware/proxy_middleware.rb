# frozen_string_literal: true

require "async/http/client"
require "async/http/endpoint"
require "async/websocket/adapters/rack"

module WrapItRuby
  module Middleware
    # Rack middleware that proxies /_proxy/{host}/{path} to the upstream host.
    #
    # Strips frame-blocking headers so responses render inside an iframe.
    # Rewrites Location headers so redirects stay within the proxy.
    # Detects WebSocket upgrades and pipes frames bidirectionally.
    #
    class ProxyMiddleware
      PATTERN = %r{\A/_proxy/(?<host>[^/]+)(?<path>/.*)?\z}

      HOP_HEADERS = %w[
        connection
        keep-alive
        proxy-authenticate
        proxy-authorization
        te
        trailers
        transfer-encoding
        upgrade
      ].freeze

      def initialize(app)
        @app     = app
        @clients = {}
      end

      def call(env)
        PATTERN.match(env["PATH_INFO"].to_s).then do |match|
          if match
            host = match[:host]
            path = match[:path] || "/"

            if websocket?(env)
              proxy_websocket(env, host, path)
            else
              proxy_http(env, host, path)
            end
          else
            @app.call(env)
          end
        end
      end

      private

      # ---- HTTP ----

      def proxy_http(env, host, path)
        client = client_for(host)

        query     = env["QUERY_STRING"]
        full_path = query && !query.empty? ? "#{path}?#{query}" : path
        headers   = forwarded_headers(env, host)
        body      = read_body(env)

        request = Protocol::HTTP::Request.new(
          "https", host, env["REQUEST_METHOD"], full_path, nil, headers, body
        )

        response = client.call(request)

        rack_body = Enumerator.new do |y|
          while (chunk = response.body&.read)
            y << chunk
          end
        ensure
          response.body&.close
        end

        rack_headers = strip_headers(response.headers, host)
        [response.status, rack_headers, rack_body]
      end

      # ---- WebSocket ----

      def websocket?(env)
        Async::WebSocket::Adapters::Rack.websocket?(env)
        false
      end

      # ---- Helpers ----

      def client_for(host)
        @clients[host] ||= Async::HTTP::Client.new(
          Async::HTTP::Endpoint.parse("https://#{host}"),
          retries: 0
        )
      end

      def forwarded_headers(env, host)
        headers = Protocol::HTTP::Headers.new

        env.each do |key, value|
          next unless key.start_with?("HTTP_")
          name = key.delete_prefix("HTTP_").downcase.tr("_", "-")
          next if name == "host" || HOP_HEADERS.include?(name)
          headers.add(name, value)
        end

        headers.add("content-type", env["CONTENT_TYPE"])     if env["CONTENT_TYPE"]
        headers.add("content-length", env["CONTENT_LENGTH"]) if env["CONTENT_LENGTH"]
        headers.add("host", host)

        headers
      end

      def strip_headers(upstream_headers, host)
        result = {}
        upstream_headers.each do |name, value|
          key = name.downcase
          next if key == "x-frame-options"
          next if key == "content-security-policy"
          next if key == "content-security-policy-report-only"
          next if key == "content-encoding"
          next if HOP_HEADERS.include?(key)
          result[name] = value
        end

        # Rewrite Location headers so redirects stay within the proxy
        if (location = result["location"] || result["Location"])
          result_key = result.key?("location") ? "location" : "Location"
          begin
            uri = URI.parse(location)
            if uri.host == host || uri.host&.end_with?(".#{host}")
              redirect_host = uri.host || host
              result[result_key] = "/_proxy/#{redirect_host}#{uri.path}#{"?#{uri.query}" if uri.query}"
            elsif uri.relative?
              result[result_key] = "/_proxy/#{host}#{location}"
            end
          rescue URI::InvalidURIError
            # leave it alone
          end
        end

        result
      end

      def read_body(env)
        input = env["rack.input"]
        return nil unless input
        body = input.read
        input.rewind rescue nil
        body && !body.empty? ? Protocol::HTTP::Body::Buffered.wrap(body) : nil
      end
    end
  end
end
