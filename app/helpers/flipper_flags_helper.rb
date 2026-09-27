# frozen_string_literal: true

module FlipperFlagsHelper
  # Non-executable JSON; ActiveSupport::JSON escapes <, >, and & so it can never contain </script>.
  def flipper_flags_script_tag
    flags = Flipper.preload_all.to_h { |feature| [ feature.name.to_s, feature.enabled?(Current.user) ] }
    tag.script(ActiveSupport::JSON.encode(flags).html_safe, type: "application/json", id: "flipper-flags")
  end
end
