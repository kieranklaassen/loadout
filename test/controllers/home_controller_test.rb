# frozen_string_literal: true

require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "GET / renders the home/index Inertia component" do
    get root_path

    assert_response :success
    assert_inertia_component "home/index"
  end

  test "the home page passes the name prop" do
    get root_path

    assert_inertia_props({ name: "Compound Stack" })
  end

  test "InertiaController shares flash and locale with every page" do
    get root_path

    assert inertia.props.key?("flash"), "flash should be shared on every Inertia page"
    assert_inertia_props({ locale: "en" })
  end
end
