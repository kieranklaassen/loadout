# frozen_string_literal: true

# What an agent can and cannot do for a member, in the words the consent screen and the
# Agents page show (R26). One source, so the copy cannot promise more or less than the
# tools do: each "can" names the tools that back it, each "can't" the words no tool may
# be named after, and a test holds both to ToolRegistry.
module Agents
  module Capabilities
    CAN = {
      "Read your toolbox, your open suggestions and your recent changes" => %w[get_my_toolbox get_recent_changes],
      "Look up the kinds of work and the catalog of tools and models" => %w[list_categories search_catalog],
      "Read what your teammates share with you, such as the tools and models they rank" => %w[get_team_rankings],
      "Add or change your picks as suggestions, which stay hidden until you confirm them" => %w[suggest_picks]
    }.freeze

    CANNOT = {
      "Confirm or dismiss suggestions, or remove or reorder your picks" => %w[confirm dismiss remove move reorder],
      "Change who can see your page" => %w[visibility],
      "Change your link or bio" => %w[handle bio],
      "Delete anything, download your history or disconnect agents" => %w[delete export history revoke disconnect]
    }.freeze

    # Approving an agent does not cover a browser agent that drives the page (KTD10).
    WEBMCP_NOTE = "A browser agent that uses WebMCP works inside your signed-in session, so it can also click buttons on the page, " \
      "including Confirm. Only let one drive your Toolbox if you trust it."

    module_function

    # The props the Agents page and the consent screen render.
    def to_prop
      { can: CAN.keys, cannot: CANNOT.keys, webmcp_note: WEBMCP_NOTE }
    end
  end
end
