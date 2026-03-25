# frozen_string_literal: true

require "async/http/client"
require "async/http/endpoint"
require "cgi"

module WrapItRuby
  module Middleware
    # Rack middleware that proxies /_proxy/{host}/{path} to the upstream host.
    #
    # Strips frame-blocking headers so responses render inside an iframe.
    # Rewrites Location headers so redirects stay within the proxy.
    # Rewrites proxy URLs in query parameters so upstream auth flows work.
    # Rewrites Set-Cookie domains to the configured cookie domain.
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
        @app          = app
        @clients      = {}
        @proxy_host   = ENV["WRAP_IT_PROXY_HOST"]
        @cookie_domain = ENV.fetch("WRAP_IT_COOKIE_DOMAIN", ".cia.net")
        @auth_host    = ENV.fetch("WRAP_IT_AUTH_HOST", "auth.cia.net")
      end

      def call(env)
        PATTERN.match(env["PATH_INFO"].to_s).then do |match|
          if match
            host = match[:host].delete_suffix(".")
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
        query     = deproxify_query(query) if query && !query.empty?
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
      #
      # WebSocket requests are handled by WebSocketProxy at the Protocol::HTTP
      # level, before they reach Rack. This detection is kept as a safety net.

      def websocket?(env)
        upgrade = env["HTTP_UPGRADE"]
        upgrade && upgrade.casecmp?("websocket")
      end

      def proxy_websocket(env, host, path)
        # Should not reach here — WebSocketProxy handles WS before Rack.
        # Return 502 as a fallback.
        [502, { "content-type" => "text/plain" }, ["WebSocket requests must be handled at Protocol::HTTP level"]]
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

          if key == "set-cookie"
            value = rewrite_cookie_domain(value)
          end

          result[name] = value
        end

        rewrite_location(result, host)

        result
      end

      # ---- Query parameter rewriting ----
      #
      # Rewrites proxy URLs embedded in query parameter values back to real
      # upstream URLs before forwarding.  This fixes auth flows where the
      # upstream validates return_url / redirect_uri against its own host.
      #
      #   https://4000.cia.net/_proxy/argocd.cia.net/applications
      #   → https://argocd.cia.net/applications
      #
      def deproxify_query(query)
        return query unless @proxy_host

        # Match both encoded and unencoded forms of the proxy URL prefix
        proxy_prefix          = "https://#{@proxy_host}/_proxy/"
        proxy_prefix_encoded  = CGI.escape("https://#{@proxy_host}/_proxy/")

        query
          .gsub(proxy_prefix_encoded) { |m| CGI.escape("https://") }
          .gsub(proxy_prefix)         { "https://" }
      end

      # ---- Redirect rewriting ----
      #
      # Rewrites Location headers so redirects stay within the proxy.
      # Auth redirects (to Authelia) are also proxied so the login page
      # renders inside the iframe — the proxy strips CSP/X-Frame-Options
      # that would otherwise block framing.
      #
      def rewrite_location(result, host)
        if (location = result["location"] || result["Location"])
          result_key = result.key?("location") ? "location" : "Location"
          begin
            uri = URI.parse(location)
            if uri.host
              result[result_key] = "/_proxy/#{uri.host.delete_suffix(".")}#{uri.path}#{"?#{uri.query}" if uri.query}"
            else
              # Resolve relative redirects (e.g. "./?folder=..." or "../foo")
              # against the upstream host to get an absolute path.
              resolved = URI.join("https://#{host}/", location)
              result[result_key] = "/_proxy/#{host}#{resolved.path}#{"?#{resolved.query}" if resolved.query}"
            end
          rescue URI::InvalidURIError
            # leave it alone
          end
        end
      end

      # ---- Cookie domain rewriting ----
      #
      # Rewrites Set-Cookie Domain attributes to the configured cookie
      # domain so the browser stores upstream cookies correctly.
      #
      #   Domain=argocd.cia.net → Domain=.cia.net
      #
      def rewrite_cookie_domain(cookie)
        cookie.gsub(/Domain=[^;]+/i, "Domain=#{@cookie_domain}")
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
