# frozen_string_literal: true

# Loads config/catalog.yml into the database. Idempotent: creates missing
# categories, tools, and models by slug and refreshes seeded fields, but never
# un-hides an item an admin hid, never undoes an admin rename, and never
# touches member-suggested items.
module Catalog
  class Sync
    PATH = Rails.root.join("config/catalog.yml")

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
        next if item.persisted? && item.created_by_id.present?

        fields = { category_slugs: Array(attrs["categories"]), position: index }
        unless item.admin_edited_at
          fields.merge!(name: attrs.fetch("name"), maker: attrs["maker"], hue: attrs.fetch("hue"), monogram: attrs.fetch("monogram").to_s)
        end
        fields.merge!(family: attrs["family"], released_on: attrs["released_on"]) if klass == AiModel
        fields[:status] = "approved" if item.new_record?
        item.update!(fields)
      end
    end
  end
end
