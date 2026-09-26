require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors get the landing page" do
    get root_path

    assert_response :success
    assert_inertia_component "home/index"
  end

  test "an onboarded member goes to their profile" do
    sign_in_as users(:every_ana)

    get root_path

    assert_redirected_to "/ana"
  end

  test "a member without a handle goes to onboarding" do
    sign_in_as users(:one)

    get root_path

    assert_redirected_to "/welcome"
  end
end
