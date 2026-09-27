class RemovePublicMapFlag < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:flipper_features)

    execute "DELETE FROM flipper_gates WHERE feature_key = #{connection.quote("public_map")}"
    execute "DELETE FROM flipper_features WHERE key = #{connection.quote("public_map")}"
  end
end
