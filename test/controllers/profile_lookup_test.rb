require "test_helper"

# Who gets a page at /:handle is decided by User#visible_to?; everyone who may not
# open a page gets the same 404 as a handle nobody claimed. (What an allowed viewer
# sees is tested with the profile and card pages themselves.)
class ProfileLookupTest < ActionDispatch::IntegrationTest
  # Production answers with public/404.html; the test environment would print the exception.
  DETAILED_EXCEPTIONS = "action_dispatch.show_detailed_exceptions".freeze

  setup do
    @detailed_exceptions = Rails.application.env_config[DETAILED_EXCEPTIONS]
    Rails.application.env_config[DETAILED_EXCEPTIONS] = false
  end

  teardown { Rails.application.env_config[DETAILED_EXCEPTIONS] = @detailed_exceptions }

  test "a page the viewer may not open is indistinguishable from an unknown handle" do
    get "/nobody-claimed-this"
    unknown = [ response.status, response.body ]
    assert_equal 404, unknown.first

    hidden = {
      "/cy" => [ nil, users(:outside_eli), users(:every_fay), users(:every_dee) ],
      "/dee" => [ nil, users(:outside_eli), users(:every_fay) ]
    }
    hidden.each do |path, viewers|
      viewers.each do |viewer|
        viewer ? sign_in_as(viewer) : sign_out
        get path

        assert_equal unknown, [ response.status, response.body ], "#{path} for #{viewer&.email_address || "a visitor"}"
      end
    end
  end

  test "the share card is public or nothing, even for the owner" do
    sign_in_as users(:every_cy)
    get "/cy/og.png"
    assert_response :not_found

    sign_in_as users(:every_dee)
    get "/dee/og.png"
    assert_response :not_found
  end
end
