# frozen_string_literal: true

require 'wrap_it_ruby/version'
require 'wrap_it_ruby/engine'

module WrapItRuby
  # Host app sets this to the class name of its menu item model.
  # When set, MenuHelper reads from the database instead of YAML.
  # Example: WrapItRuby.menu_item_class = "MenuItem"
  mattr_accessor :menu_item_class, default: nil

  def self.menu_item_model
    menu_item_class&.constantize
  end
end
