require "test_helper"

class ToolboxHostTest < ActiveSupport::TestCase
  teardown { Rails.configuration.x.public_base_url = nil }

  test "without PUBLIC_BASE_URL the display host defaults and URLs follow the request" do
    request = Struct.new(:base_url).new("http://localhost:3100")

    assert_equal "toolbox.every.to", ToolboxHost.host
    assert_equal "http://localhost:3100", ToolboxHost.base_url(request)
    assert_equal "https://toolbox.every.to", ToolboxHost.base_url
  end

  test "PUBLIC_BASE_URL is the base for URLs and the host for display" do
    Rails.configuration.x.public_base_url = "https://every.to/toolbox"
    request = Struct.new(:base_url).new("http://localhost:3100")

    assert_equal "https://every.to/toolbox", ToolboxHost.base_url(request)
    assert_equal "every.to/toolbox", ToolboxHost.host
  end

  test "paths on the host sit under the base URL's own path" do
    assert_equal "/toolbox/edit?kind=coding", ToolboxHost.path_to("/toolbox/edit?kind=coding")

    Rails.configuration.x.public_base_url = "https://every.to/toolbox"
    assert_equal "/toolbox/toolbox/edit", ToolboxHost.path_to("/toolbox/edit")

    Rails.configuration.x.public_base_url = "https://toolbox.every.to/"
    assert_equal "/webmcp/tools", ToolboxHost.path_to("/webmcp/tools")
  end

  test "a blank PUBLIC_BASE_URL counts as unset" do
    Rails.configuration.x.public_base_url = ""

    assert_equal "toolbox.every.to", ToolboxHost.host
  end

  test "the Every links are held once" do
    assert_equal "https://every.to", ToolboxHost::JOIN_EVERY_URL
    assert_equal "https://checks.every.to", ToolboxHost::ALL_VIBE_CHECKS_URL
    assert_includes AiModel::DEFAULT_VIBE_CHECK_HOSTS, URI(ToolboxHost::ALL_VIBE_CHECKS_URL).host
  end
end
