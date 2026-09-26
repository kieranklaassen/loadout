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
