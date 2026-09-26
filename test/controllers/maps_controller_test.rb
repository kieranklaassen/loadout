require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  teardown { Flipper.disable(:public_map) }

  test "an Every member sees the map with their discovery panel" do
    sign_in_as users(:every_cy)

    get map_path

    assert_response :success
    assert_inertia_component "map/index"
    assert_equal 2, inertia.props[:summary][:members]
    coding = inertia.props[:categories].find { |panel| panel[:category][:slug] == "coding" }
    assert_equal 2, coding[:people_count]
    assert_equal %w[knowledge-work video], inertia.props[:discovery][:empty_categories].map { |row| row[:category][:slug] }
  end

  test "an Every member sees a category's full ranking and public people" do
    sign_in_as users(:every_ana)

    get map_category_path("coding")

    assert_response :success
    assert_inertia_component "map/show"
    assert_equal "coding", inertia.props[:panel][:category][:slug]
    assert_equal %w[ana], inertia.props[:people].pluck(:handle)
  end

  test "someone outside Every gets the explainer, not data" do
    sign_in_as users(:one)

    get map_path

    assert_response :success
    assert_inertia_component "map/explainer"
    assert_nil inertia.props[:categories]
    assert inertia.props[:signed_in]
  end

  test "a signed-out visitor gets the explainer" do
    get map_path

    assert_response :success
    assert_inertia_component "map/explainer"
    assert_not inertia.props[:signed_in]

    get map_category_path("coding")
    assert_inertia_component "map/explainer"
  end

  test "the public_map flag opens the map to someone outside Every" do
    Flipper.enable_actor(:public_map, users(:one))
    sign_in_as users(:one)

    get map_path

    assert_response :success
    assert_inertia_component "map/index"
  end

  test "an unknown category is a 404" do
    sign_in_as users(:every_ana)

    get map_category_path("juggling")

    assert_response :not_found
  end
end
