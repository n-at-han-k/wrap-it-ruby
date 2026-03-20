# frozen_string_literal: true

require "test_helper"

class WrapItRuby::Middleware::RootRelativeProxyMiddlewareTest < Minitest::Test
  include Rack::Test::Methods

  # Capture env so we can assert on PATH_INFO after rewrite
  class PathCapture
    attr_reader :last_env

    def call(env)
      @last_env = env.dup
      [200, { "content-type" => "text/plain" }, ["ok"]]
    end
  end

  def setup
    @capture = PathCapture.new
  end

  def app
    WrapItRuby::Middleware::RootRelativeProxyMiddleware.new(@capture)
  end

  def test_proxy_paths_pass_through_unchanged
    get "/_proxy/example.com/foo"

    assert_equal "/_proxy/example.com/foo", @capture.last_env["PATH_INFO"]
    assert_equal 200, last_response.status
  end

  def test_rewrites_root_relative_with_referer
    get "/logo.png", {}, { "HTTP_REFERER" => "http://localhost/_proxy/example.com/page" }

    assert_equal "/_proxy/example.com/logo.png", @capture.last_env["PATH_INFO"]
    assert_equal 200, last_response.status
  end

  def test_no_rewrite_without_referer
    get "/logo.png"

    assert_equal "/logo.png", @capture.last_env["PATH_INFO"]
  end

  def test_no_rewrite_when_referer_has_no_proxy
    get "/logo.png", {}, { "HTTP_REFERER" => "http://localhost/normal/page" }

    assert_equal "/logo.png", @capture.last_env["PATH_INFO"]
  end

  def test_extracts_host_from_deep_referer_path
    get "/api/data", {}, { "HTTP_REFERER" => "http://localhost/_proxy/api.example.com/v1/endpoint" }

    assert_equal "/_proxy/api.example.com/api/data", @capture.last_env["PATH_INFO"]
  end
end
