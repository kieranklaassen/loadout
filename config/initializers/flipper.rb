# frozen_string_literal: true

# Feature flags (docs/modules/feature_flags.md). The signed-in User is the actor.
Flipper.register(:admins) { |actor| actor.respond_to?(:admin?) && actor.admin? }

module Flipper
  # Hydrates a checkout from the YAML registry. Runs once at boot, skips when the
  # table is not there yet (fresh clone, CI before db:prepare), and in production
  # creates every new flag DISABLED whatever the YAML says.
  def self.load_flag_defaults!
    return unless ActiveRecord::Base.connection_pool.with_connection { |c| c.data_source_exists?("flipper_features") }

    (YAML.safe_load_file(Rails.root.join("config/flipper_flag_defaults.yml")) || {}).each do |name, config|
      next if Flipper.exist?(name)

      Flipper.add(name)
      Flipper.enable(name) if config["enabled"] && !Rails.env.production?
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
    nil
  end
end

Rails.application.config.after_initialize { Flipper.load_flag_defaults! }
