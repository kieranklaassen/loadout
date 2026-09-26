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
    assert_equal "#{ToolRegistry::ENDPOINT}/whoami", webmcp_tool_path("whoami")
  end

  test "without a session it answers 401 JSON, not a sign-in redirect" do
    call_tool("whoami")

    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert_match(/sign in/i, response.parsed_body["error"])
  end

  test "runs the tool as the signed-in user and returns the MCP result" do
    sign_in_as(@user)
    call_tool("whoami")

    assert_response :success
    assert_equal false, response.parsed_body.dig("result", "isError")
    assert_equal({ "email_address" => @user.email_address }, JSON.parse(tool_text))
  end

  test "returns exactly what the MCP server returns for the same call" do
    sign_in_as(@user)
    call_tool("whoami")

    mcp = ToolRegistry.mcp_server(user: @user).handle(
      { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "whoami", arguments: {} } }
    )
    assert_equal mcp[:result].deep_stringify_keys, response.parsed_body["result"]
  end

  test "an argument that fails the input schema is an isError result" do
    sign_in_as(@user)
    call_tool("whoami", { arguments: { unexpected: true } })

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

    call_tool("whoami", "not json")
    assert_response :bad_request

    call_tool("whoami", { arguments: [ 1, 2 ] })
    assert_response :bad_request
  end

  test "tool calls are rate limited per user" do
    sign_in_as(@user)
    60.times { call_tool("whoami") }
    assert_response :success

    call_tool("whoami")
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

    def post_whoami(headers = {})
      post webmcp_tool_path("whoami"), params: { arguments: {} }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(headers)
    end

    test "rejects a session call without a CSRF token as 422 JSON" do
      post_whoami

      assert_response :unprocessable_content
      assert_match(/csrf/i, response.parsed_body["error"])
    end

    test "without a session the answer is still 401, checked before the token" do
      sign_out
      post_whoami

      assert_response :unauthorized
    end

    test "rejects a forged token" do
      post_whoami("X-CSRF-Token" => "forged")

      assert_response :unprocessable_content
    end

    test "accepts the token Inertia hands the page in the XSRF-TOKEN cookie" do
      get root_path
      token = cookies["XSRF-TOKEN"]
      assert token.present?, "Inertia should set the XSRF-TOKEN cookie"

      post_whoami("X-CSRF-Token" => CGI.unescape(token))

      assert_response :success
      assert_equal false, response.parsed_body.dig("result", "isError")
    end
  end
end
