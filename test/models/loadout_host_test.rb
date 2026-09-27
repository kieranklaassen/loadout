require "test_helper"

class LoadoutHostTest < ActiveSupport::TestCase
  teardown { Rails.configuration.x.public_base_url = nil }

  test "without PUBLIC_BASE_URL the display host defaults and URLs follow the request" do
    request = Struct.new(:base_url).new("http://localhost:3100")

    assert_equal "loadout.every.to", LoadoutHost.host
    assert_equal "http://localhost:3100", LoadoutHost.base_url(request)
    assert_equal "https://loadout.every.to", LoadoutHost.base_url
  end

  test "PUBLIC_BASE_URL is the base for URLs and the host for display" do
    Rails.configuration.x.public_base_url = "https://every.to/loadout"
    request = Struct.new(:base_url).new("http://localhost:3100")

    assert_equal "https://every.to/loadout", LoadoutHost.base_url(request)
    assert_equal "every.to/loadout", LoadoutHost.host
  end

  test "paths on the host sit under the base URL's own path" do
    assert_equal "/loadout/edit?kind=coding", LoadoutHost.path_to("/loadout/edit?kind=coding")

    Rails.configuration.x.public_base_url = "https://every.to/loadout"
    assert_equal "/loadout/loadout/edit", LoadoutHost.path_to("/loadout/edit")

    Rails.configuration.x.public_base_url = "https://loadout.every.to/"
    assert_equal "/webmcp/tools", LoadoutHost.path_to("/webmcp/tools")
  end

  test "a blank PUBLIC_BASE_URL counts as unset" do
    Rails.configuration.x.public_base_url = ""

    assert_equal "loadout.every.to", LoadoutHost.host
  end

  test "the Every links are held once" do
    assert_equal "https://every.to", LoadoutHost::JOIN_EVERY_URL
    assert_equal "https://checks.every.to", LoadoutHost::ALL_VIBE_CHECKS_URL
    assert_includes AiModel::DEFAULT_VIBE_CHECK_HOSTS, URI(LoadoutHost::ALL_VIBE_CHECKS_URL).host
  end
end
