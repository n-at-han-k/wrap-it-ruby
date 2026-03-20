module WrapItRuby
  module IframeHelper
    def iframe_wrapper(**)
      tag.div(class: "iframe-wrapper") do
        tag.iframe(**)
      end
    end
  end
end
