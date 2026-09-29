# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

class InertiaSSRTimeoutTest < ActiveSupport::TestCase
  test "timeout constant resolves to the 2-second default when env is unset" do
    assert_equal 2.0, InertiaSSRTimeout::TIMEOUT_SECONDS
  end

  test "the SSR renderer and Net::HTTP are patched with the timeout guard" do
    assert_includes InertiaRails::SSRRenderer.ancestors, InertiaSSRTimeout::SSRRendererPatch
    assert_includes Net::HTTP.singleton_class.ancestors, InertiaSSRTimeout::NetHTTPPatch
  end

  test "Net::HTTP timeouts are only injected while an SSR request is in flight" do
    # Outside an SSR request the thread flag is unset, so ordinary HTTP is untouched.
    refute Thread.current[InertiaSSRTimeout::IN_PROGRESS_KEY]
  end
end

class InertiaSSRDefaultsTest < ActionDispatch::IntegrationTest
  test "SSR is off outside production unless INERTIA_SSR_ENABLED says otherwise" do
    refute InertiaRails.configuration.ssr_enabled
  end

  test "SSR is on by default in production, and INERTIA_SSR_ENABLED=false turns it off" do
    assert_equal [ "true" ], ssr_enabled_in_production({}).lines.map(&:strip)
    assert_equal [ "false" ], ssr_enabled_in_production({ "INERTIA_SSR_ENABLED" => "false" }).lines.map(&:strip)
  end

  test "the asset build produces the SSR bundle in production" do
    assert JSON.parse(Rails.root.join("config/vite.json").read).dig("production", "ssrBuildEnabled")
  end

  test "GET / still renders the client-side Inertia component with the patch loaded" do
    get root_path

    assert_response :success
    assert_inertia_component "home/index"
  end

  private

  def ssr_enabled_in_production(env)
    Dir.mktmpdir do |dir|
      base = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "INERTIA_SSR_ENABLED" => nil, "PUBLIC_BASE_URL" => nil, "DATABASE_URL" => "sqlite3:#{dir}/production.sqlite3" }
      output, status = Open3.capture2(base.merge(env), "bin/rails", "runner", "puts InertiaRails.configuration.ssr_enabled", chdir: Rails.root.to_s)
      assert status.success?, output
      output
    end
  end
end
