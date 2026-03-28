# frozen_string_literal: true

module WrapItRuby
  class MenuItem < ApplicationRecord
    self.table_name = "menu_items"

    TYPES = %w[group internal external].freeze

    acts_as_tree order: "position"
    acts_as_list scope: :parent

    scope :roots, -> { where(parent_id: nil).order(:position) }
    scope :groups, -> { where(item_type: "group") }
    scope :internals, -> { where(item_type: "internal") }
    scope :externals, -> { where(item_type: "external") }

    before_validation :normalize_route
    before_validation :normalize_url
    before_validation :normalize_item_type

    validates :label, presence: true
    validates :icon, emoji: { allow_blank: true }
    validates :item_type, inclusion: { in: TYPES }
    validates :route, format: { with: /\A[a-z]([a-z-]*[a-z])?\z/,
                                message: "only lowercase letters and dashes allowed" },
                      uniqueness: { allow_blank: true },
                      allow_blank: true
    validates :url, format: { with: %r{\A[a-z0-9]},
                              message: "must not start with a protocol" },
                    allow_blank: true

    after_commit :reset_menu_cache

    def group?  = item_type == "group"
    def internal? = item_type == "internal"
    def external? = item_type == "external"
    def link? = internal? || external?

    # Extract the host portion from the stored url (which has no protocol).
    # e.g. "github.com/nathank/repo" → "github.com"
    def upstream_host
      return nil if url.blank?
      URI.parse("https://#{url}").host
    rescue URI::InvalidURIError
      url.split("/").first
    end

    # Extract the path portion from the stored url.
    # e.g. "github.com/nathank/repo" → "/nathank/repo"
    # e.g. "github.com"              → ""
    def url_path
      return "" if url.blank?
      uri = URI.parse("https://#{url}")
      uri.path.presence || ""
    rescue URI::InvalidURIError
      idx = url.index("/")
      idx ? url[idx..] : ""
    end

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
        item_type: hash["items"] ? "group" : normalize_entry_type(hash["type"]),
        parent_id: parent&.id,
        position:  position
      )

      hash.fetch("items", []).each_with_index do |child, pos|
        create_entry!(child, parent: item, position: pos + 1)
      end

      item
    end

    private

    def self.normalize_entry_type(type)
      case type.to_s
      when "group" then "group"
      when "external" then "external"
      when "internal", "link", "proxy", ""
        "internal"
      else
        "internal"
      end
    end

    # Normalize route to kebab-case: "MyPage" → "my-page", "/Some_Path" → "some-path"
    def normalize_route
      return if route.blank?
      self.route = route.to_s
                       .gsub(%r{[/\\]}, "")       # strip slashes
                       .underscore                 # CamelCase → snake_case
                       .gsub("_", "-")             # snake_case → kebab-case
                       .gsub(/[^a-z-]/, "")        # remove anything not lowercase or dash
                       .gsub(/-+/, "-")            # collapse consecutive dashes
                       .gsub(/\A-|-\z/, "")        # strip leading/trailing dashes
    end

    # Strip protocol and trailing slash from url.
    # "https://github.com/path/" → "github.com/path"
    def normalize_url
      return if url.blank?
      self.url = url.to_s
                    .sub(%r{\Ahttps?://}, "")      # strip protocol
                    .chomp("/")                    # strip trailing slash
    end

    def normalize_item_type
      self.item_type = self.class.normalize_entry_type(item_type)
    end

    def reset_menu_cache
      WrapItRuby::MenuHelper.reset_menu_cache! if defined?(WrapItRuby::MenuHelper)
    end
  end
end
