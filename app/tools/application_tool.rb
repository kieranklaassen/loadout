# frozen_string_literal: true

# Base class for every agent tool (docs/modules/webmcp.md). A tool is an
# MCP::Tool, so the official SDK's DSL declares it once — `tool_name`,
# `description`, `input_schema`, `annotations` — and ToolRegistry serves the
# same class to MCP clients and to WebMCP browser agents.
#
# Subclasses implement `#call` and return a String or anything JSON-serializable;
# raise ApplicationTool::Error for a failure the agent should read (it becomes
# an `isError` result, never a 500). `user` is the signed-in user the call acts
# as — tools never run without one.
class ApplicationTool < MCP::Tool
  class Error < StandardError; end

  def self.call(server_context:, **arguments)
    user = server_context[:user]
    return error_response("Sign in to use #{tool_name}.") unless user

    text_response(new(user:, arguments:).call)
  rescue Error => e
    error_response(e.message)
  end

  def self.text_response(value)
    MCP::Tool::Response.new([ { type: "text", text: value.is_a?(String) ? value : value.to_json } ])
  end

  def self.error_response(message)
    MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
  end

  attr_reader :user, :arguments

  def initialize(user:, arguments:)
    @user = user
    @arguments = arguments
  end

  def call
    raise NotImplementedError, "#{self.class.name} must implement #call"
  end
end
