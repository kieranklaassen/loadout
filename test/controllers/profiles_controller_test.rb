require "test_helper"

# One person's page at /:handle, read as the viewer. Expectations come from the fixture
# facts in test/fixtures (users.yml, entries.yml): ana shares with anyone with the link and
# ranks Cursor (with Claude Opus 5.5, 1M, high) then Claude Code for coding, and Claude for
# knowledge work; dee shares with the Every team; cy is only me; eli and fay share with
# anyone with the link.
class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include SurfaceHelper

  def kind(slug) = page_props[:kinds].find { |kind| kind[:category][:slug] == slug }
  def slugs(picks) = picks.map { |pick| [ pick[:tool][:slug], pick.dig(:model, :slug) ] }

  # A member who finished onboarding and has ranked nothing.
  def newcomer = add_person("newcomer", visibility: "only_me", team: true)

  # Who sees what

  test "a link profile renders for a visitor: the person, every kind, and the picks in rank order" do
    get "/ana"

    assert_response :success
    assert_inertia_component "profiles/show"
    assert_equal({ handle: "ana", name: "Ana Every", avatar_url: "https://every.to/avatars/ana.png" }, page_props[:person])
    assert_equal 2, page_props[:ranked_count]
    assert_equal %w[coding knowledge-work video], page_props[:kinds].map { |kind| kind[:category][:slug] }
    assert_equal [ [ "cursor", "claude-opus-5-5" ], [ "claude-code", nil ] ], slugs(kind("coding")[:picks])
    first = kind("coding")[:picks].first
    assert_equal [ 1, "1m", "high" ], first.values_at(:rank, :context, :effort)
    assert_empty kind("video")[:picks]
    assert_equal "http://www.example.com/ana", page_props[:copy_url]
  end

  test "the Profile carries no team notes, launches, recent changes, notes or owner flags" do
    get "/ana"

    assert page_props[:kinds].all? { |kind| kind[:team_uses].nil? }
    assert_empty page_props[:new_in_toolbox]
    assert_empty page_props.keys & %i[recent_changes categories is_owner profile]
  end

  test "bio is the Profile's alone: present here, absent from the read layer's person and from Home's Person view" do
    users(:every_ana).update!(bio: "Writes code and essays.")

    get "/ana"
    assert_equal "Writes code and essays.", page_props[:bio]
    assert_not_includes all_keys(page_props.slice(:person, :kinds, :new_in_toolbox, :you)), :bio

    sign_in_as users(:every_dee)
    get root_path, params: { person: "ana" }
    assert_equal "ana", page_props[:person][:person][:handle]
    assert_not_includes all_keys(page_props[:person]), :bio
  end

  test "no field on the page carries an email address" do
    users(:every_ana).update!(bio: "Writes code and essays.")
    sign_in_as users(:every_dee)

    get "/ana"

    assert_no_private_fields(page_props.slice(:person, :kinds, :new_in_toolbox, :you, :copy_url))
  end

  test "a team profile opens for a team viewer, and a link profile for any signed-in member" do
    sign_in_as users(:every_ana)
    get "/dee"
    assert_response :success
    assert_equal [ [ "claude-code", "claude-opus-5-5" ], [ "cursor", "gpt-6-astra" ] ], slugs(kind("coding")[:picks])

    sign_in_as users(:outside_eli)
    get "/ana"
    assert_response :success
  end

  test "the owner opens their own only-me profile" do
    sign_in_as users(:every_cy)

    get "/cy"

    assert_response :success
    assert_equal [ [ "cursor", "claude-opus-5" ] ], slugs(kind("coding")[:picks])
    assert_equal "200k", kind("coding")[:picks].first[:context]
  end

  test "handles are case-sensitive lowercase and reserved paths still route elsewhere" do
    get "/up"
    assert_response :success

    get "/session/new"
    assert_response :success

    get "/Ana"
    assert_response :not_found
  end

  # AE2, R13: nothing tells a hidden page from a handle nobody claimed

  test "AE2: an only-me or team profile answers a visitor and a colleague exactly like an unknown handle" do
    hidden = {
      "/cy" => [ nil, users(:outside_eli), users(:every_fay), users(:every_dee) ],
      "/dee" => [ nil, users(:outside_eli), users(:every_fay) ]
    }

    hidden.each do |path, viewers|
      viewers.each do |viewer|
        sign_in_or_out(viewer)
        who = viewer&.email_address || "a visitor"
        unknown = not_found_answer("/nobody-here")
        answer = not_found_answer(path)

        assert_equal "errors/not_found", answer.first, "#{path} for #{who}"
        assert_equal unknown, answer, "#{path} for #{who}"
        assert_not_includes response.body, User.find_by!(handle: path.delete_prefix("/")).name
      end
    end
  end

  test "AE2: a person who narrows their visibility disappears at once, and comes back when they share again" do
    get "/ana"
    assert_response :success

    users(:every_ana).update!(visibility: "only_me")
    assert_equal not_found_answer("/nobody-here"), not_found_answer("/ana")

    users(:every_ana).update!(visibility: "link")
    get "/ana"
    assert_response :success
  end

  test "a signed-out team member on a team profile gets the not-found page, and sign-in brings them back to the profile" do
    configure_every_oauth
    https!
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: "every-user-dee", email: "dee@every.to", name: "Dee Every", email_verified: true))

    get "/dee"
    assert_response :not_found
    assert_inertia_component "errors/not_found"

    get "/auth/every"
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    get "/auth/every/callback", params: { code: "authorization-code", state: state }

    assert_redirected_to "https://www.example.com/dee"
    follow_redirect!
    assert_response :success
    assert_inertia_component "profiles/show"
    assert_equal "dee", page_props[:person][:handle]
  ensure
    restore_every_oauth
  end

  test "the way back is the page the visitor asked for, never an address they supplied, and an unknown handle sets it the same way" do
    get "/dee", params: { return_to: "https://evil.example/steal", next: "https://evil.example/steal" }
    assert_response :not_found
    assert_not_includes inertia.props.to_json, "evil.example"
    assert_equal [ "www.example.com", "/dee" ], URI(session[:return_to_after_authenticating]).then { |uri| [ uri.host, uri.path ] }

    get "/nobody-here"
    assert_equal "http://www.example.com/nobody-here", session[:return_to_after_authenticating]
  end

  # Empty profiles

  test "a link profile with no picks renders the empty state and the site default image" do
    add_person("newbie", visibility: "link", name: "Newbie Person")

    get "/newbie"

    assert_response :success
    assert_equal 0, page_props[:ranked_count]
    assert page_props[:kinds].all? { |kind| kind[:picks].empty? }
    assert_select "meta[property='og:image'][content$='/og-default.png']"
    assert_select "meta[property='og:image'][content*='/newbie/og.png']", count: 0
    assert_select "meta[name=robots]", count: 0
  end

  test "a team profile with no picks renders the empty state for a team viewer" do
    add_person("quiet", visibility: "team", team: true)
    sign_in_as users(:every_dee)

    get "/quiet"

    assert_response :success
    assert_equal 0, page_props[:ranked_count]
  end

  # Compare with mine

  test "a signed-in member with picks can compare: their own picks by kind" do
    sign_in_as users(:every_dee)

    get "/ana"

    assert page_props[:viewer_can_compare]
    assert_equal %w[coding knowledge-work], page_props[:you].keys.map(&:to_s)
    assert_equal [ [ "claude-code", "claude-opus-5-5" ], [ "cursor", "gpt-6-astra" ] ], slugs(page_props[:you][:coding])
    assert_equal "medium", page_props[:you][:coding].first[:effort]
  end

  test "only the kinds the viewer ranked are in you" do
    sign_in_as users(:outside_eli)

    get "/ana"

    assert_equal %w[coding video], page_props[:you].keys.map(&:to_s)
  end

  test "a visitor, a member with nothing ranked and the owner cannot compare" do
    get "/ana"
    assert_equal [ false, {} ], [ page_props[:viewer_can_compare], page_props[:you] ]

    sign_in_as newcomer
    get "/ana"
    assert_equal [ false, {} ], [ page_props[:viewer_can_compare], page_props[:you] ]

    sign_in_as users(:every_ana)
    get "/ana"
    assert_equal [ false, {} ], [ page_props[:viewer_can_compare], page_props[:you] ]
  end

  test "the viewer's pending picks are their own to compare with" do
    secret = add_tool("Secret Tool", status: "pending")
    add_pick(users(:every_dee), :video, 1, secret)
    sign_in_as users(:every_dee)

    get "/ana"

    pick = page_props[:you][:video].first
    assert_equal [ "secret-tool", true ], [ pick[:tool][:slug], pick[:tool][:pending] ]
  end

  # Pending catalog items

  test "a pick on a pending tool or model shows to its owner, marked, and to nobody else" do
    secret_tool = add_tool("Secret Tool", status: "pending")
    secret_model = add_model("Secret Model", status: "pending")
    add_pick(users(:every_ana), :coding, 3, secret_tool)
    add_pick(users(:every_ana), :video, 1, tools(:runway), model: secret_model)

    get "/ana"
    assert_equal [ [ "cursor", "claude-opus-5-5" ], [ "claude-code", nil ] ], slugs(kind("coding")[:picks])
    assert_equal [ [ "runway", nil ] ], slugs(kind("video")[:picks])
    assert_not_includes response.body, "Secret"

    sign_in_as users(:every_dee)
    get "/ana"
    assert_not_includes response.body, "Secret"

    sign_in_as users(:every_ana)
    get "/ana"
    assert_equal [ "secret-tool", true ], kind("coding")[:picks].last[:tool].values_at(:slug, :pending)
    assert_equal [ "secret-model", true ], kind("video")[:picks].first[:model].values_at(:slug, :pending)
  end

  # KTD19

  test "responses are private, revalidated and vary by cookie, found or not" do
    [ "/ana", "/nobody-here" ].each do |path|
      get path

      assert_never_shared_cacheable(path)
      assert_includes response.headers["Cache-Control"].split(/,\s*/), "must-revalidate", path
    end
  end

  # Link preview

  test "link preview meta tags describe a link-visible profile and point at its card" do
    get "/ana"

    assert_select "title", text: "Ana Every's toolbox"
    assert_select "meta[property='og:title'][content=?]", "Ana Every's toolbox"
    assert_select "meta[property='og:description'][content=?]",
      "Ana Every's top picks: Cursor with Claude Opus 5.5 for coding and Claude with Claude Opus 5.5 for knowledge work."
    assert_select "meta[property='og:image'][content=?]", "http://www.example.com/ana/og.png?v=#{users(:every_ana).loadout_updated_at.to_i}"
    assert_select "meta[property='og:url'][content=?]", "http://www.example.com/ana"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name=robots]", count: 0
  end

  test "a profile shared with the team is noindex and does not point at a card" do
    sign_in_as users(:every_ana)

    get "/dee"

    assert_select "meta[name=robots][content=noindex]"
    assert_select "meta[property='og:image'][content$='/og-default.png']"
  end

  test "an only-me profile is noindex and does not point at a card, even for its owner" do
    sign_in_as users(:every_cy)

    get "/cy"

    assert_select "meta[name=robots][content=noindex]"
    assert_select "meta[property='og:image'][content$='/og-default.png']"
  end

  test "the preview of a profile with no picks says so" do
    add_person("newbie", visibility: "link", name: "Newbie Person")

    get "/newbie"

    assert_select "meta[property='og:description'][content=?]", "Newbie Person hasn't ranked their AI tools yet."
  end

  test "the link to copy and the card come from the configured public address" do
    Rails.configuration.x.public_base_url = "https://toolbox.example.test"

    get "/ana"

    assert_equal "https://toolbox.example.test/ana", page_props[:copy_url]
    assert_select "meta[property='og:url'][content=?]", "https://toolbox.example.test/ana"
    assert_select "meta[property='og:image'][content^='https://toolbox.example.test/ana/og.png']"
  ensure
    Rails.configuration.x.public_base_url = nil
  end

  test "the preview does not depend on who is looking" do
    get "/ana"
    visitor = preview_meta
    sign_in_as users(:every_dee)
    get "/ana"

    assert_equal visitor, preview_meta
  end
end
