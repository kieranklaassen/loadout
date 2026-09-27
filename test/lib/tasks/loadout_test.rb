require "test_helper"
require "rake"

class LoadoutTasksTest < ActiveSupport::TestCase
  RESOURCE = "http://www.example.com/mcp"

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("loadout:remove_member")
  end

  test "remove_member deletes the person with their picks, history, suggestions, periods, sessions and agent grants" do
    ana = users(:every_ana)
    dee_picks = users(:every_dee).entries.count
    client = connect_client("Cursor")
    grant = OauthGrant.issue!(user: ana, client:, resource: RESOURCE, scope: "loadout")
    code = issue_code(client, ana)
    ana.sessions.create!
    Tool.create!(name: "Ana's Find", status: "pending", created_by: ana)
    agent_suggestion(ana, client)
    assert_operator ana.entries.count, :>, 0
    assert_operator ana.entry_changes.count, :>, 0
    assert_operator ana.visibility_periods.count, :>, 0

    output = run_task("loadout:remove_member", EMAIL: " Ana@Every.to ")

    assert_match(/ana@every\.to/, output)
    assert_not User.exists?(ana.id)
    assert_empty [ Entry, EntryChange, PickSuggestion, VisibilityPeriod, Session, OauthGrant, OauthAuthorizationCode ].flat_map { |model| model.where(user_id: ana.id).to_a }
    assert_nil OauthGrant.authenticate(grant.access_token, resource: RESOURCE)
    assert_not OauthAuthorizationCode.exists?(code.id)
    assert_nil Tool.find_by!(name: "Ana's Find").created_by_id, "what they added to the catalog stays"
    assert_equal dee_picks, users(:every_dee).entries.count
    assert users(:every_cy).sessions.create!.persisted?
  end

  test "remove_member with an unknown or missing email deletes nothing" do
    assert_no_difference [ -> { User.count }, -> { Entry.count } ] do
      assert_raises(SystemExit) { run_task("loadout:remove_member", EMAIL: "nobody@every.to") }
      assert_raises(SystemExit) { run_task("loadout:remove_member", EMAIL: "") }
    end
  end

  test "revoke_agent_grants ends every grant and its unused codes, and withdraws open agent suggestions only" do
    ana, dee = users(:every_ana), users(:every_dee)
    cursor_client, codex_client = connect_client("Cursor"), connect_client("Codex")
    first = OauthGrant.issue!(user: ana, client: cursor_client, resource: RESOURCE, scope: "loadout")
    second = OauthGrant.issue!(user: dee, client: codex_client, resource: RESOURCE, scope: "loadout")
    earlier = OauthGrant.issue!(user: dee, client: cursor_client, resource: RESOURCE, scope: "loadout")
    earlier.update!(revoked_at: 3.days.ago)
    revoked_then = earlier.reload.revoked_at
    unused_code = issue_code(cursor_client, ana)
    open_agent = agent_suggestion(ana, cursor_client)
    open_other_agent = agent_suggestion(dee, codex_client)
    confirmed_agent = agent_suggestion(dee, codex_client, status: "confirmed", tool: tools(:cursor))
    webmcp = pick_suggestions(:ana_runway)
    entries_before = Entry.count

    output = run_task("loadout:revoke_agent_grants")

    assert_match(/2 grants/, output)
    assert_empty OauthGrant.active
    assert_nil OauthGrant.authenticate(first.access_token, resource: RESOURCE)
    assert_nil OauthGrant.authenticate(second.access_token, resource: RESOURCE)
    assert_equal revoked_then, earlier.reload.revoked_at, "an earlier revocation keeps its time"
    assert_not OauthAuthorizationCode.exists?(unused_code.id)
    [ open_agent, open_other_agent ].each do |suggestion|
      suggestion.reload
      assert_equal "withdrawn", suggestion.status
      assert_not_nil suggestion.resolved_at
    end
    assert_equal "confirmed", confirmed_agent.reload.status
    assert_equal "open", webmcp.reload.status, "a WebMCP suggestion has no OAuth client to revoke"
    assert_equal entries_before, Entry.count
  end

  test "revoke_agent_grants with nothing connected changes nothing" do
    output = run_task("loadout:revoke_agent_grants")

    assert_match(/0 grants/, output)
    assert_equal "open", pick_suggestions(:ana_runway).status
  end

  private

  def run_task(name, **env)
    original = env.keys.to_h { |key| [ key.to_s, ENV[key.to_s] ] }
    env.each { |key, value| ENV[key.to_s] = value }
    task = Rake::Task[name]
    task.reenable
    capture_io { task.invoke }.first
  ensure
    original&.each { |key, value| ENV[key] = value }
  end

  def connect_client(name)
    OauthClient.create!(client_name: name, redirect_uris: [ "http://127.0.0.1:8123/callback" ])
  end

  def issue_code(client, user)
    OauthAuthorizationCode.issue!(client:, user:, redirect_uri: client.redirect_uris.first, code_challenge: "challenge", resource: RESOURCE, scope: "loadout")
  end

  def agent_suggestion(user, client, status: "open", tool: tools(:runway))
    PickSuggestion.create!(user:, category: categories(:video), tool:, status:, oauth_client_id: client.id, client_name: client.client_name)
  end
end
