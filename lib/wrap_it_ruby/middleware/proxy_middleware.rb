# frozen_string_literal: true

require 'async/http/client'
require 'async/http/endpoint'
require 'cgi'

module WrapItRuby
  module Middleware
    # Rack middleware that proxies /_proxy/{host}/{path} to the upstream host.
    #
    # Header strategy (both request and response):
    #   1. Whitelist — only known-safe headers pass through
    #   2. Modify   — rewrite values (host, origin, cookies, redirects)
    #   3. Add      — set headers the upstream/browser needs
    #
    class ProxyMiddleware
      PATTERN = %r{\A/_proxy/(?<host>[^/]+)(?<path>/.*)?\z}

      # ── Request headers whitelisted for forwarding to upstream ──
      #
      # Everything not on this list is dropped. This prevents leaking
      # proxy-internal headers, browser metadata, and hop-by-hop headers.
      #
      REQUEST_WHITELIST = %w[
        accept
        accept-language
        authorization
        cache-control
        content-type
        content-length
        cookie
        if-match
        if-modified-since
        if-none-match
        if-range
        if-unmodified-since
        pragma
        range
        x-requested-with
      ].to_set.freeze

      # ── Response headers whitelisted for forwarding to browser ──
      #
      # Everything not on this list is dropped. This prevents frame-
      # blocking headers, CSP, HSTS, and hop-by-hop headers from
      # reaching the browser inside the iframe.
      #
      RESPONSE_WHITELIST = %w[
        accept-ranges
        age
        cache-control
        content-disposition
        content-language
        content-length
        content-range
        content-type
        date
        etag
        expires
        last-modified
        location
        pragma
        retry-after
        set-cookie
        vary
        x-content-type-options
        x-xss-protection
      ].to_set.freeze

      def initialize(app)
        @app          = app
        @clients      = {}
        @proxy_host   = ENV['WRAP_IT_PROXY_HOST']
        @cookie_domain = ENV.fetch('WRAP_IT_COOKIE_DOMAIN', '.cia.net')
      end

      def call(env)
        PATTERN.match(env['PATH_INFO'].to_s).then do |match|
          if match
            host = match[:host].delete_suffix('.')
            path = match[:path] || '/'

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

      # ── HTTP proxying ──

      def proxy_http(env, host, path)
        client = client_for(host)

        query     = env['QUERY_STRING']
        query     = deproxify_query(query) if query && !query.empty?
        full_path = (query && !query.empty?) ? "#{path}?#{query}" : path
        headers   = build_request_headers(env, host)
        body      = read_body(env)

        request = Protocol::HTTP::Request.new(
          'https', host, env['REQUEST_METHOD'], full_path, nil, headers, body
        )

        response = client.call(request)

        rack_body = Enumerator.new do |y|
          while (chunk = response.body&.read)
            y << chunk
          end
        ensure
          response.body&.close
        end

        rack_headers = build_response_headers(response.headers, host)
        [response.status, rack_headers, rack_body]
      end

      # ── WebSocket (safety net — handled by WebSocketProxy before Rack) ──

      def websocket?(env)
        upgrade = env['HTTP_UPGRADE']
        upgrade && upgrade.casecmp?('websocket')
      end

      def proxy_websocket(_env, _host, _path)
        [502, { 'content-type' => 'text/plain' }, ['WebSocket requests must be handled at Protocol::HTTP level']]
      end

      # ── Request headers: whitelist → modify → add ──

      def build_request_headers(env, host)
        headers = Protocol::HTTP::Headers.new

        # 1. Whitelist: only forward known-safe headers
        env.each do |key, value|
          next unless key.start_with?('HTTP_')

          name = key.delete_prefix('HTTP_').downcase.tr('_', '-')
          next unless REQUEST_WHITELIST.include?(name)

          headers.add(name, value)
        end

        # Also forward content-type/content-length from Rack env
        headers.add('content-type', env['CONTENT_TYPE'])     if env['CONTENT_TYPE']
        headers.add('content-length', env['CONTENT_LENGTH']) if env['CONTENT_LENGTH']

        # 2. Modify: nothing to modify at this stage (cookies pass through
        #    as-is since the .cia.net domain covers both proxy and upstream)

        # 3. Add: set host for the upstream
        headers.add('host', host)

        headers
      end

      # ── Response headers: whitelist → modify → add ──

      def build_response_headers(upstream_headers, host)
        result = {}

        # 1. Whitelist: only pass through known-safe headers
        upstream_headers.each do |name, value|
          key = name.downcase
          next unless RESPONSE_WHITELIST.include?(key)

          # 2. Modify: rewrite specific headers
          case key
          when 'set-cookie'
            value = rewrite_cookie_domain(value)
          when 'location'
            # Handled below after the loop
          end

          result[name] = value
        end

        # Rewrite Location header (redirects stay within proxy)
        rewrite_location(result, host)

        result
      end

      # ── Helpers ──

      def client_for(host)
        @clients[host] ||= Async::HTTP::Client.new(
          Async::HTTP::Endpoint.parse("https://#{host}"),
          retries: 0
        )
      end

      # Rewrites proxy URLs in query parameter values back to real upstream
      # URLs. Fixes auth flows where upstream validates return_url against
      # its own host.
      def deproxify_query(query)
        return query unless @proxy_host

        proxy_prefix          = "https://#{@proxy_host}/_proxy/"
        proxy_prefix_encoded  = CGI.escape("https://#{@proxy_host}/_proxy/")

        query
          .gsub(proxy_prefix_encoded) { |_m| CGI.escape('https://') }
          .gsub(proxy_prefix)         { 'https://' }
      end

      # Rewrites Location headers so redirects stay within the proxy.
      def rewrite_location(result, host)
        if (location = result['location'] || result['Location'])
          result_key = result.key?('location') ? 'location' : 'Location'
          begin
            uri = URI.parse(location)
            if uri.host
              result[result_key] = "/_proxy/#{uri.host.delete_suffix('.')}#{uri.path}#{"?#{uri.query}" if uri.query}"
            else
              resolved = URI.join("https://#{host}/", location)
              result[result_key] = "/_proxy/#{host}#{resolved.path}#{"?#{resolved.query}" if resolved.query}"
            end
          rescue URI::InvalidURIError
            # leave it alone
          end
        end
      end

      # Rewrites Set-Cookie Domain to the configured cookie domain.
      def rewrite_cookie_domain(cookie)
        cookie.gsub(/Domain=[^;]+/i, "Domain=#{@cookie_domain}")
      end

      def read_body(env)
        input = env['rack.input']
        return nil unless input

        body = input.read
        begin
          input.rewind
        rescue StandardError
          nil
        end
        (body && !body.empty?) ? Protocol::HTTP::Body::Buffered.wrap(body) : nil
      end
    end
  end
end
