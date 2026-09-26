class CreateCatalogAndEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.string :blurb
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :categories, :slug, unique: true

    %i[tools ai_models].each do |table|
      create_table table do |t|
        t.string :slug, null: false
        t.string :name, null: false
        t.string :maker
        t.integer :hue, null: false, default: 220
        t.string :monogram, null: false
        t.string :status, null: false, default: "approved"
        t.json :category_slugs, null: false, default: []
        t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
        t.integer :position, null: false, default: 0
        if table == :ai_models
          t.string :family
          t.date :released_on
        end
        t.timestamps
      end
      add_index table, :slug, unique: true
      add_index table, :status
    end

    create_table :entries do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :category, null: false, foreign_key: true
      t.references :tool, null: false, foreign_key: true
      t.references :ai_model, foreign_key: true
      t.string :note
      t.boolean :primary, null: false, default: false
      t.timestamps
    end
    add_index :entries, %i[user_id category_id tool_id ai_model_id], unique: true, name: "index_entries_uniqueness"

    create_table :entry_changes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :category, null: false, foreign_key: true
      t.references :tool, null: false, foreign_key: true
      t.references :ai_model, foreign_key: true
      t.string :action, null: false
      t.string :source, null: false
      t.string :client_name
      t.json :details, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :entry_changes, %i[user_id created_at]
  end
end
