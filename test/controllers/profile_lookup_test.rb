require "test_helper"

# Who gets a page at /:handle is decided by User#visible_to?; everyone who may not
# open a page gets the same not-found answer as a handle nobody claimed. (The profile
# page's answer is tested in profiles_controller_test.)
class ProfileLookupTest < ActionDispatch::IntegrationTest
  test "the share card is public or nothing, even for the owner" do
    sign_in_as users(:every_cy)
    get "/cy/og.png"
    assert_response :not_found

    sign_in_as users(:every_dee)
    get "/dee/og.png"
    assert_response :not_found
  end
end
