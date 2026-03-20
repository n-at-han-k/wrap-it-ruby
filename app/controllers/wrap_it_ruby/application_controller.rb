# frozen_string_literal: true

module WrapItRuby
  class ApplicationController < ::ApplicationController
    include WrapItRuby::Menu

    layout "wrap_it_ruby/application"
  end
end
