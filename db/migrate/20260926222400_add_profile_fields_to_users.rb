class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.remove :password_digest, type: :string, null: false
      t.string :every_user_id
      t.string :name
      t.string :avatar_url
      t.string :handle
      t.string :bio
      t.boolean :public, null: false, default: false
      t.boolean :admin, null: false, default: false
      t.datetime :loadout_updated_at
      t.datetime :onboarded_at
    end
    add_index :users, :every_user_id, unique: true
    add_index :users, :handle, unique: true
  end
end
