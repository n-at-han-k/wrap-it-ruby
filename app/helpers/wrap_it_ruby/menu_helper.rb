# frozen_string_literal: true

module WrapItRuby
  # View helper that exposes menu_config and related queries to templates.
  # Delegates to WrapItRuby::Menu for the actual loading logic.
  module MenuHelper
    include WrapItRuby::Menu
  end
end
