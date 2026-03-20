# frozen_string_literal: true

require "test_helper"

class WrapItRuby::IframeHelperTest < Minitest::Test
  include WrapItRuby::IframeHelper

  # Provide the tag helper that ActionView would normally give us.
  def tag
    @tag ||= ActionView::Base.new(
      ActionView::LookupContext.new([]),
      {},
      nil
    ).tag
  end

  def test_iframe_wraps_in_div
    result = iframe(src: "/foo", class: "test")
    html = result.to_s

    assert_includes html, 'class="iframe-wrapper"'
    assert_includes html, "<iframe"
    assert_includes html, 'src="/foo"'
  end

  def test_iframe_passes_attributes
    result = iframe(src: "/bar", width: "100%", height: "500")
    html = result.to_s

    assert_includes html, 'width="100%"'
    assert_includes html, 'height="500"'
  end
end
