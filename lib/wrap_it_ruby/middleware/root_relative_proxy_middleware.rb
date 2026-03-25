# frozen_string_literal: true

module WrapItRuby
  module Middleware
    # Handles root-relative requests (e.g. /logo.png, /api/data) that originate
    # from within a proxied iframe page.
    #
    # Detects the proxy host from two sources (in priority order):
    #
    #   1. Referer header -- contains /_proxy/{host}/... for requests where the
    #      browser sends the full path. Works for both scripted requests and
    #      asset loads (<img>, <link>, <script>).
    #
    #   2. X-Proxy-Host header -- set by the interception script on fetch/XHR.
    #      Signals the request came from inside the proxy.
    #
    # For programmatic requests (fetch/XHR) that carry X-Proxy-Host, the path
    # is rewritten inline to /_proxy/{host}{path}.
    #
    # For browser-initiated requests (script/link/img tags), a 307 redirect is
    # returned instead.  This ensures the browser's URL for the resource retains
    # the /_proxy/{host} prefix, which keeps the Referer chain intact for any
    # sub-resources loaded by that resource (e.g. a JS module that imports
    # another module via a root-relative path).
    #
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
            proxy_path = "#{PROXY_PREFIX}/#{host}#{path}"

            if env[PROXY_HOST_HEADER]
              # Programmatic request (fetch/XHR) — rewrite inline.
              # interception.js already sets the correct Referer and
              # X-Proxy-Host header so the chain won't break.
              env["PATH_INFO"] = proxy_path
            else
              # Browser-initiated request — redirect so the browser's URL
              # (and thus Referer for any sub-resource loads) retains the
              # /_proxy/{host} prefix.
              query = env["QUERY_STRING"]
              proxy_path += "?#{query}" unless query.nil? || query.empty?
              return [307, { "location" => proxy_path }, []]
            end
          end
        end

        @app.call(env)
      end

      private

      def extract_proxy_host(env)
        # 1. Try the Referer path (works for browser-initiated asset loads)
        referer = env["HTTP_REFERER"]
        if referer
          match = REFERER_PATTERN.match(referer)
          return match[:host].delete_suffix(".") if match
        end

        # 2. Fall back to X-Proxy-Host header (set by interception.js on
        #    fetch/XHR — covers cases where the Referer lost the /_proxy/
        #    prefix after a server-side rewrite hop)
        env[PROXY_HOST_HEADER]&.delete_suffix(".")
      end
    end
  end
end
