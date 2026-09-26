class CreateOauthTables < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_clients do |t|
      t.string :client_id, null: false, index: { unique: true }
      t.string :client_name, null: false
      t.json :redirect_uris, null: false, default: []
      t.string :software_id
      t.string :software_version
      t.string :client_uri
      t.string :logo_uri
      t.timestamps
    end

    create_table :oauth_grants do |t|
      t.references :user, null: false, foreign_key: true
      t.references :oauth_client, null: false, foreign_key: true
      t.string :resource, null: false
      t.string :scope, null: false
      t.string :access_digest, null: false, index: { unique: true }
      t.datetime :access_expires_at, null: false
      t.string :refresh_digest, null: false, index: { unique: true }
      t.datetime :refresh_expires_at, null: false
      t.string :previous_refresh_digest, index: true
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end

    create_table :oauth_authorization_codes do |t|
      t.string :code_digest, null: false, index: { unique: true }
      t.references :oauth_client, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :oauth_grant, foreign_key: true
      t.string :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.string :resource, null: false
      t.string :scope, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
  end
end
