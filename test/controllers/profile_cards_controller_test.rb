require "test_helper"

class ProfileCardsControllerTest < ActionDispatch::IntegrationTest
  include SurfaceHelper

  # Production answers with public/404.html; the test environment would print the exception.
  DETAILED_EXCEPTIONS = "action_dispatch.show_detailed_exceptions".freeze

  setup do
    @detailed_exceptions = Rails.application.env_config[DETAILED_EXCEPTIONS]
    Rails.application.env_config[DETAILED_EXCEPTIONS] = false
  end

  teardown { Rails.application.env_config[DETAILED_EXCEPTIONS] = @detailed_exceptions }

  test "a link profile with picks gets a 1200x630 PNG" do
    get "/ana/og.png"

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal [ 1200, 630 ], Vips::Image.new_from_buffer(response.body, "").size
  end

  test "AE2: an only me or team profile's card is the same 404 as an unknown handle, for every viewer" do
    get "/nobody-claimed-this/og.png"
    unknown = [ response.status, response.body ]
    assert_equal 404, unknown.first

    {
      "/cy/og.png" => [ nil, users(:every_cy), users(:every_dee), users(:every_ana), users(:outside_eli) ],
      "/dee/og.png" => [ nil, users(:every_dee), users(:every_ana), users(:outside_eli) ]
    }.each do |path, viewers|
      viewers.each do |viewer|
        sign_in_or_out(viewer)
        get path

        assert_equal unknown, [ response.status, response.body ], "#{path} for #{viewer&.email_address || "a visitor"}"
      end
    end
  end

  test "narrowing visibility ends the card at once, even for a browser that holds the old ETag" do
    get "/ana/og.png"
    etag = response.headers["ETag"]

    users(:every_ana).update!(visibility: "only_me")
    get "/ana/og.png", headers: { "If-None-Match" => etag }

    assert_response :not_found
    users(:every_ana).update!(visibility: "team")
    get "/ana/og.png", headers: { "If-None-Match" => etag }
    assert_response :not_found
  end

  test "a link profile with no confirmed pick, or only pending ones, is a 404" do
    add_person("quiet")
    pending = add_person("pending")
    add_pick(pending, Category.create!(slug: "kind", name: "Kind", position: 10), 1, add_tool("Secret Tool", status: "pending"))

    get "/nobody-claimed-this/og.png"
    unknown = [ response.status, response.body ]

    %w[quiet pending].each do |handle|
      get "/#{handle}/og.png"

      assert_equal unknown, [ response.status, response.body ], handle
    end
  end

  test "the card is drawn for a visitor whoever asks, so a signed-in viewer or the owner gets the same card" do
    owner_only = add_tool("Owner Only", status: "pending")
    add_pick(users(:every_ana), Category.create!(slug: "kind", name: "Kind", position: 10), 1, owner_only)
    get "/ana/og.png"
    visitor = [ response.headers["ETag"], response.body ]

    [ users(:every_dee), users(:outside_eli), users(:every_ana) ].each do |viewer|
      sign_in_as viewer
      get "/ana/og.png"

      assert_equal visitor, [ response.headers["ETag"], response.body ], viewer.email_address
    end
    assert_not_includes ProfileCard.new(users(:every_ana)).to_svg, "Owner Only"
  end

  test "the card revalidates on every request: no-cache and a strong ETag, never public or max-age" do
    get "/ana/og.png"

    assert_equal "no-cache", response.headers["Cache-Control"]
    assert_match(/\A"\h+"\z/, response.headers["ETag"], "a strong ETag")
  end

  test "a request that already holds the ETag is a 304 without a body" do
    get "/ana/og.png"
    etag = response.headers["ETag"]

    get "/ana/og.png", headers: { "If-None-Match" => etag }

    assert_response :not_modified
    assert_empty response.body
    assert_equal "no-cache", response.headers["Cache-Control"]
    assert_equal etag, response.headers["ETag"]
  end

  test "the ETag is the same for what is not drawn and changes with what is" do
    get "/ana/og.png"
    etag = response.headers["ETag"]

    users(:every_ana).update!(bio: "A new bio", loadout_updated_at: Time.current)
    entries(:ana_claude_code).update!(effort: "high")
    get "/ana/og.png", headers: { "If-None-Match" => etag }
    assert_response :not_modified, "a bio and a second choice are not on the card"

    entries(:ana_cursor).update!(tool: tools(:runway))
    get "/ana/og.png", headers: { "If-None-Match" => etag }

    assert_response :success
    assert_not_equal etag, response.headers["ETag"]
  end

  test "bumping the card version changes the ETag, so old cards are dropped" do
    get "/ana/og.png"
    etag = response.headers["ETag"]

    with_card_version(ProfileCard::VERSION + 1) do
      get "/ana/og.png", headers: { "If-None-Match" => etag }

      assert_response :success
      assert_not_equal etag, response.headers["ETag"]
    end
  end

  test "an admin editing a mark gives the card a new ETag and a new picture" do
    get "/ana/og.png"
    etag, before = response.headers["ETag"], response.body

    tools(:cursor).update!(mark: "cursor")
    get "/ana/og.png", headers: { "If-None-Match" => etag }

    assert_response :success
    assert_not_equal etag, response.headers["ETag"]
    assert_not_equal before, response.body
  end

  private

  def with_card_version(version)
    original = ProfileCard::VERSION
    ProfileCard.send(:remove_const, :VERSION)
    ProfileCard.const_set(:VERSION, version)
    yield
  ensure
    ProfileCard.send(:remove_const, :VERSION)
    ProfileCard.const_set(:VERSION, original)
  end
end
