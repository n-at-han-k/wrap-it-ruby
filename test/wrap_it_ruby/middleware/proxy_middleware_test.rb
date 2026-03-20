# frozen_string_literal: true

require "test_helper"

class WrapItRuby::Middleware::ProxyMiddlewareTest < Minitest::Test
  include Rack::Test::Methods

  def inner_app
    ->(_env) { [200, { "content-type" => "text/plain" }, ["inner app"]] }
  end

  def app
    WrapItRuby::Middleware::ProxyMiddleware.new(inner_app)
  end

  def test_non_proxy_path_passes_through
    get "/some/normal/path"

    assert_equal 200, last_response.status
    assert_equal "inner app", last_response.body
  end

  def test_proxy_pattern_matches_host_and_path
    pattern = WrapItRuby::Middleware::ProxyMiddleware::PATTERN

    match = pattern.match("/_proxy/example.com/foo/bar")
    assert match
    assert_equal "example.com", match[:host]
    assert_equal "/foo/bar", match[:path]
  end

  def test_proxy_pattern_matches_host_only
    pattern = WrapItRuby::Middleware::ProxyMiddleware::PATTERN

    match = pattern.match("/_proxy/example.com")
    assert match
    assert_equal "example.com", match[:host]
    assert_nil match[:path]
  end

  def test_proxy_pattern_rejects_non_proxy_paths
    pattern = WrapItRuby::Middleware::ProxyMiddleware::PATTERN

    assert_nil pattern.match("/foo/bar")
    assert_nil pattern.match("/proxy/example.com")
  end

  def test_strip_headers_removes_frame_blocking
    middleware = WrapItRuby::Middleware::ProxyMiddleware.new(inner_app)
    upstream = Protocol::HTTP::Headers.new
    upstream.add("content-type", "text/html")
    upstream.add("x-frame-options", "DENY")
    upstream.add("content-security-policy", "default-src 'self'")
    upstream.add("content-security-policy-report-only", "default-src 'self'")

    result = middleware.send(:strip_headers, upstream, "example.com")

    assert result.key?("content-type")
    refute result.key?("x-frame-options")
    refute result.key?("content-security-policy")
    refute result.key?("content-security-policy-report-only")
  end

  def test_strip_headers_rewrites_location_for_same_host
    middleware = WrapItRuby::Middleware::ProxyMiddleware.new(inner_app)
    upstream = Protocol::HTTP::Headers.new
    upstream.add("location", "https://example.com/new-path?q=1")

    result = middleware.send(:strip_headers, upstream, "example.com")

    assert_equal "/_proxy/example.com/new-path?q=1", result["location"]
  end

  def test_strip_headers_rewrites_relative_location
    middleware = WrapItRuby::Middleware::ProxyMiddleware.new(inner_app)
    upstream = Protocol::HTTP::Headers.new
    upstream.add("location", "/relative/path")

    result = middleware.send(:strip_headers, upstream, "example.com")

    assert_equal "/_proxy/example.com/relative/path", result["location"]
  end

  def test_strip_headers_leaves_external_location_alone
    middleware = WrapItRuby::Middleware::ProxyMiddleware.new(inner_app)
    upstream = Protocol::HTTP::Headers.new
    upstream.add("location", "https://other.com/path")

    result = middleware.send(:strip_headers, upstream, "example.com")

    assert_equal "https://other.com/path", result["location"]
  end

  def test_hop_headers_are_stripped
    middleware = WrapItRuby::Middleware::ProxyMiddleware.new(inner_app)
    upstream = Protocol::HTTP::Headers.new
    upstream.add("connection", "keep-alive")
    upstream.add("transfer-encoding", "chunked")
    upstream.add("content-type", "text/html")

    result = middleware.send(:strip_headers, upstream, "example.com")

    refute result.key?("connection")
    refute result.key?("transfer-encoding")
    assert result.key?("content-type")
  end
end
