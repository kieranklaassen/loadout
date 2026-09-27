class AddAdminEditedAtToCatalogItems < ActiveRecord::Migration[8.1]
  def change
    add_column :tools, :admin_edited_at, :datetime
    add_column :ai_models, :admin_edited_at, :datetime
  end
end
