# frozen_string_literal: true

require "test_helper"

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

class InertiaSSRDisabledByDefaultTest < ActionDispatch::IntegrationTest
  test "SSR is disabled by default" do
    refute InertiaRails.configuration.ssr_enabled,
      "SSR must ship disabled by default (enable via INERTIA_SSR_ENABLED)"
  end

  test "GET / still renders the client-side Inertia component with the patch loaded" do
    get root_path

    assert_response :success
    assert_inertia_component "home/index"
  end
end
