class RemovePublicMapFlag < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:flipper_features)

    execute "DELETE FROM flipper_gates WHERE feature_key = #{connection.quote("public_map")}"
    execute "DELETE FROM flipper_features WHERE key = #{connection.quote("public_map")}"
  end

  # The flag comes back disabled, as Flipper creates every flag in production.
  def down
    return unless table_exists?(:flipper_features)

    execute <<~SQL
      INSERT INTO flipper_features (key, created_at, updated_at)
      SELECT #{connection.quote("public_map")}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      WHERE NOT EXISTS (SELECT 1 FROM flipper_features WHERE key = #{connection.quote("public_map")})
    SQL
  end
end
