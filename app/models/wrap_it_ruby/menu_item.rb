# frozen_string_literal: true

module WrapItRuby
  class MenuItem < ApplicationRecord
    self.table_name = "menu_items"

    acts_as_tree order: "position"
    acts_as_list scope: :parent

    scope :roots, -> { where(parent_id: nil).order(:position) }
    scope :groups, -> { where(item_type: "group") }
    scope :links, -> { where(item_type: "link") }

    validates :label, presence: true
    validates :icon, emoji: { allow_blank: true }

    after_commit :reset_menu_cache

    def group?  = item_type == "group"
    def link?   = item_type == "link"

    # Move item to a new parent and position.
    # Handles acts_as_list scope change without triggering NOT NULL on position.
    def move_to(new_parent_id, position)
      return insert_at(position) if parent_id.to_s == new_parent_id.to_s

      # Close gap in old scope
      acts_as_list_class.where(scope_condition)
                        .where("position > ?", self.position)
                        .update_all("position = position - 1")

      # Place at bottom of new scope temporarily
      new_bottom = acts_as_list_class.where(parent_id: new_parent_id).maximum(:position).to_i + 1
      update_columns(parent_id: new_parent_id, position: new_bottom)
      reload

      # Now insert_at works within the new scope
      insert_at(position)
    end

    # Seed the menu_items table from a YAML menu config file.
    def self.seed_from_yaml!(path)
      transaction do
        destroy_all
        entries = YAML.load_file(path)
        entries.each_with_index do |entry, pos|
          create_entry!(entry, parent: nil, position: pos + 1)
        end
      end
    end

    def self.create_entry!(hash, parent:, position:)
      item = create!(
        label:     hash["label"],
        icon:      hash["icon"],
        route:     hash["route"],
        url:       hash["url"],
        item_type: hash["items"] ? "group" : (hash["type"] || "link"),
        parent_id: parent&.id,
        position:  position
      )

      hash.fetch("items", []).each_with_index do |child, pos|
        create_entry!(child, parent: item, position: pos + 1)
      end

      item
    end

    private

    def reset_menu_cache
      WrapItRuby::MenuHelper.reset_menu_cache! if defined?(WrapItRuby::MenuHelper)
    end
  end
end
