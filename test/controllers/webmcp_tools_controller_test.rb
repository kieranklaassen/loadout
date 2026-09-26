# frozen_string_literal: true

require "test_helper"

class WebmcpToolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    WebmcpToolsController::RATE_LIMIT_STORE.clear
  end

  def call_tool(name, body = { arguments: {} }, headers: {})
    post webmcp_tool_path(name), params: body.is_a?(String) ? body : body.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }.merge(headers)
  end

  def tool_text
    response.parsed_body.dig("result", "content", 0, "text")
  end

  test "the route path matches ToolRegistry::ENDPOINT" do
    assert_equal "#{ToolRegistry::ENDPOINT}/list_categories", webmcp_tool_path("list_categories")
  end

  test "without a session it answers 401 JSON, not a sign-in redirect" do
    call_tool("list_categories")

    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert_match(/sign in/i, response.parsed_body["error"])
  end

  test "runs the tool as the signed-in user and returns the MCP result" do
    sign_in_as(@user)
    call_tool("list_categories")

    assert_response :success
    assert_equal false, response.parsed_body.dig("result", "isError")
    assert_equal Category.count, JSON.parse(tool_text)["categories"].size
  end

  test "writes through the browser record source webmcp and no client name" do
    sign_in_as(@user)
    call_tool("update_loadout", { arguments: { operations: [ { op: "add", category: "video", tool: "runway" } ] } })

    assert_response :success
    assert_equal false, response.parsed_body.dig("result", "isError"), tool_text
    assert_equal [ "webmcp", nil ], @user.entry_changes.sole.values_at(:source, :client_name)
  end

  test "returns exactly what the MCP server returns for the same call" do
    sign_in_as(@user)
    call_tool("list_categories")

    mcp = ToolRegistry.mcp_server(user: @user, source: "webmcp").handle(
      { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "list_categories", arguments: {} } }
    )
    assert_equal mcp[:result].deep_stringify_keys, response.parsed_body["result"]
  end

  test "an argument that fails the input schema is an isError result" do
    sign_in_as(@user)
    call_tool("list_categories", { arguments: { unexpected: true } })

    assert_response :success
    assert_equal true, response.parsed_body.dig("result", "isError")
    assert_match(/unexpected/, tool_text)
  end

  test "an unknown tool is 404" do
    sign_in_as(@user)
    call_tool("no_such_tool")

    assert_response :not_found
    assert_match(/no_such_tool/, response.parsed_body["error"])
  end

  test "a malformed body is 400" do
    sign_in_as(@user)

    call_tool("list_categories", "not json")
    assert_response :bad_request

    call_tool("list_categories", { arguments: [ 1, 2 ] })
    assert_response :bad_request
  end

  test "tool calls are rate limited per user" do
    sign_in_as(@user)
    60.times { call_tool("list_categories") }
    assert_response :success

    call_tool("list_categories")
    assert_response :too_many_requests
    assert_equal "application/json", response.media_type
  end

  class CsrfTest < ActionDispatch::IntegrationTest
    setup do
      @forgery_protection = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      WebmcpToolsController::RATE_LIMIT_STORE.clear
      sign_in_as(users(:one))
    end

    teardown do
      ActionController::Base.allow_forgery_protection = @forgery_protection
    end

    def post_list_categories(headers = {})
      post webmcp_tool_path("list_categories"), params: { arguments: {} }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(headers)
    end

    test "rejects a session call without a CSRF token as 422 JSON" do
      post_list_categories

      assert_response :unprocessable_content
      assert_match(/csrf/i, response.parsed_body["error"])
    end

    test "without a session the answer is still 401, checked before the token" do
      sign_out
      post_list_categories

      assert_response :unauthorized
    end

    test "rejects a forged token" do
      post_list_categories("X-CSRF-Token" => "forged")

      assert_response :unprocessable_content
    end

    test "accepts the token Inertia hands the page in the XSRF-TOKEN cookie" do
      get root_path
      token = cookies["XSRF-TOKEN"]
      assert token.present?, "Inertia should set the XSRF-TOKEN cookie"

      post_list_categories("X-CSRF-Token" => CGI.unescape(token))

      assert_response :success
      assert_equal false, response.parsed_body.dig("result", "isError")
    end
  end
end
