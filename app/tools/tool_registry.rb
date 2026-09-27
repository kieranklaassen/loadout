# frozen_string_literal: true

# The one list of agent tools (docs/modules/webmcp.md). Both surfaces read it:
#
# - MCP clients: `ToolRegistry.mcp_server(user:, source: "mcp", client_name:)`
#   is the MCP::Server McpController mounts on Streamable HTTP.
# - WebMCP browser agents: `ToolRegistry.manifest` is the shared Inertia prop the
#   page registers on the browser's model context, and `ToolRegistry.call` runs
#   a registered tool for WebmcpToolsController through that same MCP::Server,
#   so a browser call and an MCP `tools/call` return the identical result.
#
# The list is explicit rather than discovered through `inherited`: Zeitwerk
# loads app/tools lazily in development, so self-registration would miss any
# tool nothing had referenced yet. `bin/rails g tool Name` appends here.
module ToolRegistry
  TOOLS = [
    ListCategoriesTool,
    SearchCatalogTool,
    GetMyLoadoutTool,
    GetRecentChangesTool
  ].freeze

  # Must match the `webmcp_tool` route in config/routes.rb.
  ENDPOINT = "/webmcp/tools"

  INSTRUCTIONS = <<~TEXT.squish
    Loadout is a profile of the AI tools and models a member uses for each kind of work
    (coding, knowledge work, writing, research, image, video, and more). You act for the
    signed-in member. Read their loadout with get_my_loadout and find catalog slugs with
    search_catalog. Ask the member before you guess: only record tools and models they
    confirm they use.
  TEXT

  module_function

  def tools
    TOOLS
  end

  def find(name)
    TOOLS.find { |tool| tool.tool_name == name }
  end

  # `source` is "mcp" or "webmcp"; `client_name` names the OAuth client over MCP.
  # Both are recorded on every change a tool writes.
  def mcp_server(user:, source:, client_name: nil)
    MCP::Server.new(
      name: Rails.application.class.module_parent_name.underscore,
      instructions: INSTRUCTIONS,
      tools: TOOLS,
      server_context: { user:, source:, client_name: }
    )
  end

  # Tool definitions for the page, in the MCP `tools/list` shape (`inputSchema`,
  # camelCase annotations) that WebMCP's `registerTool` also takes.
  def manifest
    {
      endpoint: ENDPOINT,
      tools: TOOLS.map { |tool| tool.to_h.slice(:name, :description, :inputSchema, :annotations) }
    }
  end

  # Returns the MCP `CallToolResult` hash (`content`, `isError`), or nil when no
  # tool has that name. Argument validation failures are `isError` results.
  def call(name, arguments:, user:, source:, client_name: nil)
    return unless find(name)

    response = mcp_server(user:, source:, client_name:).handle(
      { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: } }
    )
    response[:result] || error_result(response.dig(:error, :message) || "Tool call failed")
  end

  def error_result(message)
    { content: [ { type: "text", text: message } ], isError: true }
  end
end
