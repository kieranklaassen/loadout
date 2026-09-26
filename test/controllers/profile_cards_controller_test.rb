require "test_helper"

class ProfileCardsControllerTest < ActionDispatch::IntegrationTest
  test "a public profile's card is a cacheable 1200x630 PNG" do
    get "/ana/og.png"

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=300"

    image = Vips::Image.new_from_buffer(response.body, "")
    assert_equal [ 1200, 630 ], [ image.width, image.height ]
  end

  test "a private profile's card is a 404, even for its owner" do
    get "/cy/og.png"
    assert_response :not_found

    sign_in_as users(:every_cy)
    get "/cy/og.png"
    assert_response :not_found
  end

  test "an unknown handle's card is a 404" do
    get "/nobody-here/og.png"

    assert_response :not_found
  end
end
