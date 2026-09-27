require "test_helper"

class HandlesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "answers a partial reload with the availability prop" do
    get check_handle_path, params: { handle: "Fresh" }, headers: partial_headers("onboarding/show")

    assert_response :success
    assert_equal({ "handle" => "fresh", "available" => true, "message" => "loadout.every.to/fresh is yours." }, response.parsed_body["props"]["availability"])
  end

  test "reports taken and reserved handles" do
    get check_handle_path, params: { handle: "ana" }, headers: partial_headers("onboarding/show")
    assert_equal false, response.parsed_body["props"]["availability"]["available"]

    get check_handle_path, params: { handle: "admin" }, headers: partial_headers("onboarding/show")
    assert_equal "loadout.every.to/admin is reserved.", response.parsed_body["props"]["availability"]["message"]
  end

  test "a member's own handle is available to them in settings" do
    sign_in_as users(:every_ana)

    get check_handle_path, params: { handle: "ana" }, headers: partial_headers("settings/show")

    assert response.parsed_body["props"]["availability"]["available"]
  end

  test "a plain visit or another page's partial is sent back to the page" do
    get check_handle_path, params: { handle: "fresh" }
    assert_redirected_to welcome_path

    get check_handle_path, params: { handle: "fresh" }, headers: partial_headers("home/index")
    assert_response :redirect
  end

  test "each address gets 60 checks a minute; the next answer still reaches the page as an unavailable handle" do
    60.times do
      get check_handle_path, params: { handle: "fresh" }, headers: partial_headers("onboarding/show")
      assert response.parsed_body["props"]["availability"]["available"]
    end

    get check_handle_path, params: { handle: "Fresh" }, headers: partial_headers("onboarding/show")

    assert_response :too_many_requests
    availability = response.parsed_body["props"]["availability"]
    assert_equal false, availability["available"]
    assert_equal "fresh", availability["handle"]
    assert_match(/too many checks/i, availability["message"])
  end

  test "one address running out of checks does not limit another" do
    61.times { get check_handle_path, params: { handle: "fresh" }, headers: partial_headers("onboarding/show") }
    assert_response :too_many_requests

    get check_handle_path, params: { handle: "fresh" }, headers: partial_headers("onboarding/show"), env: { "REMOTE_ADDR" => "203.0.113.9" }

    assert_response :success
    assert response.parsed_body["props"]["availability"]["available"]
  end

  private

  def partial_headers(component)
    {
      "X-Inertia" => "true",
      "X-Inertia-Version" => InertiaRails.configuration.version.to_s,
      "X-Inertia-Partial-Component" => component,
      "X-Inertia-Partial-Data" => "availability"
    }
  end
end
