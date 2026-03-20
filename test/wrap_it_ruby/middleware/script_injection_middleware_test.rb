# frozen_string_literal: true

require "test_helper"

class WrapItRuby::Middleware::ScriptInjectionMiddlewareTest < Minitest::Test
  include Rack::Test::Methods

  def html_app(body = "<html><head><title>Test</title></head><body>Hi</body></html>")
    ->(_env) { [200, { "content-type" => "text/html; charset=utf-8" }, [body]] }
  end

  def json_app
    ->(_env) { [200, { "content-type" => "application/json" }, ['{"ok":true}']] }
  end

  def app
    @app_instance || WrapItRuby::Middleware::ScriptInjectionMiddleware.new(html_app)
  end

  def test_injects_script_into_html_proxy_response
    @app_instance = WrapItRuby::Middleware::ScriptInjectionMiddleware.new(html_app)
    get "/_proxy/example.com/page"

    body = last_response.body
    assert_includes body, "window.__proxyHost"
    assert_includes body, '"example.com"'
    assert_includes body, '<base href="/_proxy/example.com/">'
  end

  def test_injects_hosting_site
    @app_instance = WrapItRuby::Middleware::ScriptInjectionMiddleware.new(html_app)
    get "/_proxy/example.com/page", {}, { "HTTP_HOST" => "myapp.test" }

    assert_includes last_response.body, "window.__hostingSite"
    assert_includes last_response.body, '"myapp.test"'
  end

  def test_does_not_inject_into_non_proxy_paths
    @app_instance = WrapItRuby::Middleware::ScriptInjectionMiddleware.new(html_app)
    get "/normal/path"

    body = last_response.body
    refute_includes body, "window.__proxyHost"
    assert_includes body, "<head>"
  end

  def test_does_not_inject_into_non_html_responses
    @app_instance = WrapItRuby::Middleware::ScriptInjectionMiddleware.new(json_app)
    get "/_proxy/example.com/api"

    assert_equal '{"ok":true}', last_response.body
  end

  def test_updates_content_length_after_injection
    @app_instance = WrapItRuby::Middleware::ScriptInjectionMiddleware.new(html_app)
    get "/_proxy/example.com/page"

    expected_length = last_response.body.bytesize.to_s
    assert_equal expected_length, last_response.headers["content-length"]
  end

  def test_strips_accept_encoding_for_proxy_requests
    env_capture = nil
    capturing_app = lambda do |env|
      env_capture = env.dup
      [200, { "content-type" => "text/html" }, ["<html><head></head></html>"]]
    end
    @app_instance = WrapItRuby::Middleware::ScriptInjectionMiddleware.new(capturing_app)
    get "/_proxy/example.com/page", {}, { "HTTP_ACCEPT_ENCODING" => "gzip, deflate" }

    refute env_capture.key?("HTTP_ACCEPT_ENCODING")
  end

  def test_injection_before_head_content
    html = "<html><head><meta charset='utf-8'></head><body></body></html>"
    @app_instance = WrapItRuby::Middleware::ScriptInjectionMiddleware.new(html_app(html))
    get "/_proxy/example.com/"

    body = last_response.body
    head_idx = body.index("<head>")
    script_idx = body.index("<script>")
    meta_idx = body.index("<meta")

    assert head_idx, "Expected <head> in body"
    assert script_idx, "Expected <script> in body"
    assert script_idx < meta_idx, "Script should be injected before existing head content"
  end

  def test_prepends_when_no_head_tag
    html = "<html><body>No head here</body></html>"
    @app_instance = WrapItRuby::Middleware::ScriptInjectionMiddleware.new(html_app(html))
    get "/_proxy/example.com/"

    body = last_response.body
    assert body.start_with?("<base"), "Should prepend tags when no <head> found"
  end
end
