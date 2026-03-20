# frozen_string_literal: true

module WrapItRuby
  module IframeHelper
    def iframe(**)
      tag.div(class: "iframe-wrapper") do
        tag.iframe(**)
      end
    end
  end
end
