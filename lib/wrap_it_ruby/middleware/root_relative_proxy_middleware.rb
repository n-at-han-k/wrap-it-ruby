# frozen_string_literal: true

module WrapItRuby
  module Middleware
    # Handles root-relative requests (e.g. /logo.png, /api/data) that originate
    # from within a proxied iframe page.
    #
    # Detects the proxy host from two sources (in priority order):
    #
    #   1. X-Proxy-Host header -- set by the interception script on fetch/XHR.
    #      Signals the request came from inside the proxy. The actual upstream
    #      host is resolved from the Referer header.
    #
    #   2. Referer header -- contains /_proxy/{host}/... for requests where the
    #      browser sends the full path. Works for both scripted requests and
    #      asset loads (<img>, <link>, <script>).
    #
    # Rewrites PATH_INFO to /_proxy/{host}{path} so ProxyMiddleware handles it.
    # Must be inserted BEFORE ProxyMiddleware in the Rack stack.
    #
    class RootRelativeProxyMiddleware
      PROXY_PREFIX = "/_proxy"
      PROXY_HOST_HEADER = "HTTP_X_PROXY_HOST"
      REFERER_PATTERN = %r{/_proxy/(?<host>[^/]+)}

      def initialize(app)
        @app = app
      end

      def call(env)
        path = env["PATH_INFO"].to_s

        unless path.start_with?(PROXY_PREFIX)
          host = extract_proxy_host(env)
          if host
            env["PATH_INFO"] = "#{PROXY_PREFIX}/#{host}#{path}"
          end
        end

        @app.call(env)
      end

      private

      def extract_proxy_host(env)
        referer = env["HTTP_REFERER"]
        match = REFERER_PATTERN.match(referer) if referer
        match[:host] if match
      end
    end
  end
end
