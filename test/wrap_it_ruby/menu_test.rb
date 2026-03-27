# frozen_string_literal: true

require 'test_helper'

class WrapItRuby::MenuHelperTest < Minitest::Test
  FIXTURE_MENU = File.join(FIXTURES_PATH, 'menu.yml')

  def setup
    WrapItRuby::MenuHelper.instance_variable_set(:@menu_config, nil)
    fixture = FIXTURE_MENU
    WrapItRuby::MenuHelper.define_method(:menu_file) { Pathname.new(fixture) }
  end

  def teardown
    WrapItRuby::MenuHelper.instance_variable_set(:@menu_config, nil)
    WrapItRuby::MenuHelper.define_method(:menu_file) { Rails.root.join('config/menu.yml') }
  end

  def test_menu_config_loads_yaml
    config = WrapItRuby::MenuHelper.menu_config
    assert_kind_of Array, config
    assert_equal 3, config.size
    assert_equal 'Dashboard', config[0]['label']
  end

  def test_all_menu_items_flattens_nested_items
    items = WrapItRuby::MenuHelper.all_menu_items
    labels = items.map { |i| i['label'] }

    assert_includes labels, 'Dashboard'
    assert_includes labels, 'Docs'
    assert_includes labels, 'API'
    assert_includes labels, 'About'
    assert_equal 6, items.size
  end

  def test_all_menu_items_flattens_deeply_nested_items
    items = WrapItRuby::MenuHelper.all_menu_items
    labels = items.map { |i| i['label'] }

    assert_includes labels, 'Guides'
    assert_includes labels, 'Getting Started'
  end

  def test_all_proxy_menu_items_filters_by_type
    proxy_items = WrapItRuby::MenuHelper.all_proxy_menu_items
    proxy_items.each do |item|
      assert_equal 'proxy', item['type']
    end
    assert_equal 3, proxy_items.size
  end

  def test_proxy_paths_returns_routes_with_leading_slash
    paths = WrapItRuby::MenuHelper.proxy_paths
    assert_includes paths, '/dashboard'
    assert_includes paths, '/api'
    assert_includes paths, '/getting-started'
    refute_includes paths, '/about'
  end

  def test_proxy_route_match_exact_segment
    assert WrapItRuby::MenuHelper.proxy_route_match?("/github", "github")
    assert WrapItRuby::MenuHelper.proxy_route_match?("/github/foo/bar", "github")
    refute WrapItRuby::MenuHelper.proxy_route_match?("/github-actions", "github")
    refute WrapItRuby::MenuHelper.proxy_route_match?("/git", "github")
  end

  def test_proxy_route_checks_all_items
    assert WrapItRuby::MenuHelper.proxy_route?("/dashboard")
    assert WrapItRuby::MenuHelper.proxy_route?("/dashboard/some/path")
    assert WrapItRuby::MenuHelper.proxy_route?("/api")
    refute WrapItRuby::MenuHelper.proxy_route?("/about")
    refute WrapItRuby::MenuHelper.proxy_route?("/unknown")
  end

  def test_menu_href_with_url_containing_path
    entry = { 'route' => 'github', 'url' => 'github.com/nathank/repo' }
    assert_equal '/github/nathank/repo', WrapItRuby::MenuHelper.menu_href(entry)
  end

  def test_menu_href_with_url_domain_only
    entry = { 'route' => 'ebay', 'url' => 'ebay.co.uk' }
    assert_equal '/ebay', WrapItRuby::MenuHelper.menu_href(entry)
  end

  def test_menu_href_without_url
    entry = { 'route' => 'about' }
    assert_equal '/about', WrapItRuby::MenuHelper.menu_href(entry)
  end

  def test_menu_href_with_blank_route
    entry = { 'route' => nil }
    assert_nil WrapItRuby::MenuHelper.menu_href(entry)
  end

  def test_menu_is_includable
    obj = Object.new
    obj.extend(WrapItRuby::MenuHelper)
    fixture = FIXTURE_MENU
    obj.define_singleton_method(:menu_file) { Pathname.new(fixture) }

    assert_kind_of Array, obj.menu_config
  end
end
