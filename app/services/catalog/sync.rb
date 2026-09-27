# frozen_string_literal: true

# Loads config/catalog.yml into the database. Idempotent: creates missing
# categories, tools, and models by slug and refreshes seeded fields, but never
# un-hides an item an admin hid, never undoes an admin rename, and never
# touches member-suggested items. A model's release date and Vibe Check link
# belong to the admin: the catalog only fills them while they are blank and the
# model has never been edited by an admin. Categories are never deleted.
module Catalog
  class Sync
    PATH = Rails.root.join("config/catalog.yml")
    LAUNCH_FIELDS = %w[released_on vibe_check_url].freeze

    def self.call(path: PATH) = new(path).call

    def initialize(path)
      @data = YAML.safe_load_file(path, permitted_classes: [ Date ]) || {}
    end

    def call
      ApplicationRecord.transaction do
        sync_categories
        sync_items(Tool, @data.fetch("tools", []))
        sync_items(AiModel, @data.fetch("models", []))
      end
    end

    private

    def sync_categories
      @data.fetch("categories", []).each_with_index do |attrs, index|
        category = Category.find_or_initialize_by(slug: attrs.fetch("slug"))
        category.update!(name: attrs.fetch("name"), blurb: attrs["blurb"], position: index)
      end
    end

    def sync_items(klass, rows)
      rows.each_with_index do |attrs, index|
        item = klass.find_or_initialize_by(slug: attrs.fetch("slug"))
        monogram = monogram_of(attrs)
        next if item.persisted? && item.created_by_id.present?

        fields = { category_slugs: Array(attrs["categories"]), position: index, mark: attrs["mark"] }
        unless item.admin_edited_at
          fields.merge!(name: attrs.fetch("name"), maker: attrs["maker"], hue: attrs.fetch("hue"), monogram:)
        end
        fields.merge!(family: attrs["family"], **launch_fields(item, attrs)) if klass == AiModel
        fields[:status] = "approved" if item.new_record?
        item.update!(fields)
      end
    end

    # YAML reads a bare No, On or Off as a boolean, so a monogram must be a quoted string.
    def monogram_of(attrs)
      attrs.fetch("monogram").tap do |value|
        raise ArgumentError, "#{attrs["slug"]}: monogram #{value.inspect} is not a string, quote it in the catalog" unless value.is_a?(String)
      end
    end

    def launch_fields(item, attrs)
      return {} if item.admin_edited_at

      LAUNCH_FIELDS.filter_map { |field| [ field.to_sym, attrs[field] ] if item[field].blank? && attrs[field].present? }.to_h
    end
  end
end
