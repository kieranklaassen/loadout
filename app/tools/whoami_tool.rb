# frozen_string_literal: true

# Example tool: replace or delete it once the app has real tools.
class WhoamiTool < ApplicationTool
  tool_name "whoami"
  description "Returns the email address of the signed-in user this agent is acting for."
  input_schema(properties: {}, required: [], additionalProperties: false)
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    { email_address: user.email_address }
  end
end
