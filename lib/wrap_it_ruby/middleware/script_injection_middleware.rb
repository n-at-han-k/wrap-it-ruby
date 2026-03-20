# frozen_string_literal: true

module WrapItRuby
  module Middleware
    # Injects interception.js inline into HTML responses from the proxy.
    #
    # - Strips Accept-Encoding from proxy requests so upstream sends
    #   uncompressed HTML (avoids decompress/recompress just to inject).
    # - Buffers HTML responses and injects the script as the first child
    #   of <head>.
    # - Extracts the proxy host from PATH_INFO and injects it as
    #   window.__proxyHost so the script works even when the browser URL
    #   doesn't contain /_proxy/ (e.g. after root-relative navigation).
    # - Injects window.__hostingSite so the interception script knows
    #   which host is the proxy server itself.
    # - Reads the script file once and caches it.
    #
    class ScriptInjectionMiddleware
      PROXY_PREFIX = "/_proxy/"
      SCRIPT_FILE  = File.expand_path("../../../app/assets/javascripts/wrap_it_ruby/interception.js", __dir__).freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        path = env["PATH_INFO"].to_s

        if path.start_with?(PROXY_PREFIX)
          host = path.delete_prefix(PROXY_PREFIX).split("/", 2).first
          hosting_site = env["HTTP_HOST"]

          env.delete("HTTP_ACCEPT_ENCODING")
          status, headers, body = @app.call(env)

          if html_response?(headers)
            body = inject_script(body, headers, host, hosting_site)
          end

          [status, headers, body]
        else
          @app.call(env)
        end
      end

      private

      def script_source
        @script_source ||= File.read(SCRIPT_FILE)
      end

      def html_response?(headers)
        ct = headers["content-type"] || headers["Content-Type"] || ""
        ct.include?("text/html")
      end

      def inject_script(body, headers, host, hosting_site)
        html = +""
        body.each { |chunk| html << chunk }
        body.close if body.respond_to?(:close)
        html.force_encoding("UTF-8")

        tag = "<base href=\"/_proxy/#{host}/\">" \
          "<script>" \
          "window.__proxyHost=#{host.to_json};" \
          "window.__hostingSite=#{hosting_site.to_json};" \
          "#{script_source}" \
          "</script>"

        unless html.sub!(%r{(<head[^>]*>)}i, "\\1#{tag}")
          html.prepend(tag)
        end

        headers.delete("content-length")
        headers["content-length"] = html.bytesize.to_s
        [html]
      end
    end
  end
end
