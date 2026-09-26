# frozen_string_literal: true

# Executes one ToolRegistry tool for a WebMCP browser agent (docs/modules/webmcp.md).
#
# This is the one sanctioned JSON endpoint beside Inertia pages: tool
# definitions still travel as the `webmcp` shared prop, but the browser's model
# context calls a tool long after the page rendered. It acts as the signed-in
# user through the session cookie, so it is CSRF-protected like any form POST,
# and answers JSON (never a redirect) when either check fails.
#
#   POST /webmcp/tools/:name  { "arguments": { ... } }
#   200 { "result": <MCP CallToolResult> }  — including tool errors (isError)
#   400 malformed body · 401 no session · 404 unknown tool · 422 bad CSRF token
class WebmcpToolsController < ApplicationController
  include Authentication

  protect_from_forgery with: :exception
  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { error: "Invalid CSRF token. Reload the page and try again." }, status: :unprocessable_content
  end

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 60, within: 1.minute, store: RATE_LIMIT_STORE,
             by: -> { Current.session.user_id },
             with: -> { render json: { error: "Too many tool calls. Try again in a minute." }, status: :too_many_requests }

  def create
    arguments = parsed_arguments
    return render json: { error: "Send a JSON body of the form {\"arguments\": {...}}." }, status: :bad_request unless arguments

    result = ToolRegistry.call(params[:name], arguments:, user: Current.session.user)
    return render json: { error: "Unknown tool: #{params[:name]}" }, status: :not_found unless result

    render json: { result: }
  end

  private
    def request_authentication
      render json: { error: "Sign in to use this app's tools." }, status: :unauthorized
    end

    def parsed_arguments
      body = JSON.parse(request.raw_post.presence || "{}")
      arguments = body.fetch("arguments", {}) if body.is_a?(Hash)
      arguments if arguments.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end
end
